"""Console chat client for a running ninfer-serve instance.

Streams tokens as they arrive, shows the thinking chain separately from the
final answer, and prints a per-turn token/speed summary.
"""

import argparse
import json
import sys
import time
import urllib.error
import urllib.request

# Windows: bypass any system proxy so 127.0.0.1 is reached directly.
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def parse_args():
    p = argparse.ArgumentParser(description="Chat with a local NInfer server.")
    p.add_argument("--base", default="http://127.0.0.1:8080")
    p.add_argument("--model", default="bonsai2-27b")
    p.add_argument("--temperature", type=float, default=0.6)
    p.add_argument("--max-tokens", type=int, default=2048)
    p.add_argument("--thinking", action="store_true", default=True,
                   help="enable the reasoning chain (default on)")
    return p.parse_args()


def stats_line(usage, timings, elapsed, ttft, reasoning_chars):
    parts = []
    if usage:
        comp = usage.get("completion_tokens")
        prompt = usage.get("prompt_tokens")
        total = usage.get("total_tokens")
        if comp is not None:
            parts.append("输出 %s tok" % comp)
            if elapsed > 0:
                parts.append("%.1f tok/s" % (comp / elapsed))
        if prompt is not None:
            cached = (usage.get("prompt_tokens_details") or {}).get("cached_tokens")
            parts.append("提示 %s tok" % prompt + ("(缓存 %s)" % cached if cached else ""))
        if total is not None:
            parts.append("合计 %s tok" % total)
    if elapsed:
        parts.append("用时 %.1fs" % elapsed)
    if ttft is not None:
        parts.append("首字 %dms" % (ttft * 1000))
    if timings:
        dec = timings.get("predicted_per_second")
        pre = timings.get("prompt_per_second")
        if dec:
            parts.append("解码 %.1f tok/s" % dec)
        if pre:
            parts.append("预填 %.1f tok/s" % pre)
    if usage and usage.get("reasoning_tokens"):
        parts.append("思维 %s tok" % usage["reasoning_tokens"])
    return "── " + " · ".join(parts) if parts else ""


def chat_turn(base, model, messages, temperature, max_tokens, thinking):
    payload = {
        "model": model,
        "messages": messages,
        "stream": True,
        "stream_options": {"include_usage": True},
        "temperature": temperature,
        "max_tokens": max_tokens,
        "enable_thinking": thinking,
    }
    req = urllib.request.Request(
        base + "/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    return OPENER.open(req, timeout=600)


def run_turn(base, model, messages, temperature, max_tokens, thinking):
    """Stream one turn. Returns (reasoning, answer, usage, timings, elapsed, ttft)."""
    reasoning, answer = [], []
    usage, timings = None, None
    ttft = None
    t0 = time.perf_counter()
    resp = chat_turn(base, model, messages, temperature, max_tokens, thinking)
    buf = b""
    mode = None
    with resp:
        while True:
            chunk = resp.read1(65536)
            if not chunk:
                break
            buf += chunk
            lines = buf.split(b"\n")
            buf = lines.pop()
            for raw in lines:
                s = raw.decode("utf-8", "replace").strip()
                if not s.startswith("data:"):
                    continue
                data = s[5:].strip()
                if not data or data == "[DONE]":
                    continue
                try:
                    j = json.loads(data)
                except json.JSONDecodeError:
                    continue
                if j.get("usage"):
                    usage = j["usage"]
                if j.get("timings"):
                    timings = j["timings"]
                delta = (j.get("choices") or [{}])[0].get("delta") or {}
                piece = delta.get("reasoning_content") or delta.get("content")
                if not piece:
                    continue
                if ttft is None:
                    ttft = time.perf_counter() - t0
                new_mode = "think" if delta.get("reasoning_content") else "text"
                if new_mode != mode:
                    mode = new_mode
                    print("\n[thinking] " if mode == "think" else "\n[answer] ",
                          end="", flush=True)
                (reasoning if mode == "think" else answer).append(piece)
                print(piece, end="", flush=True)
    elapsed = time.perf_counter() - t0
    return "".join(reasoning), "".join(answer), usage, timings, elapsed, ttft


def main():
    args = parse_args()
    base, model = args.base.rstrip("/"), args.model
    temperature, max_tokens, thinking = args.temperature, args.max_tokens, args.thinking
    messages = []
    last = None

    print("NInfer console chat | model %s | %s" % (model, base))
    print("commands: /clear /think /temp N /max N /stats /exit\n")

    while True:
        try:
            text = input("you> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break
        if not text:
            continue
        if text == "/exit":
            break
        if text == "/clear":
            messages.clear()
            print("(conversation cleared)")
            continue
        if text == "/think":
            thinking = not thinking
            print("(thinking %s)" % ("on" if thinking else "off"))
            continue
        if text == "/stats":
            print(last[4] if last else "(no stats yet)")
            continue
        if text.startswith("/temp"):
            try:
                temperature = float(text.split()[1])
                print("(temperature %.2f)" % temperature)
            except (IndexError, ValueError):
                print("usage: /temp 0.8")
            continue
        if text.startswith("/max"):
            try:
                max_tokens = int(text.split()[1])
                print("(max tokens %d)" % max_tokens)
            except (IndexError, ValueError):
                print("usage: /max 4096")
            continue

        messages.append({"role": "user", "content": text})
        print("ai> ", end="", flush=True)
        try:
            reasoning, answer, usage, timings, elapsed, ttft = run_turn(
                base, model, messages, temperature, max_tokens, thinking)
        except urllib.error.HTTPError as exc:
            print("\n[HTTP %d] %s" % (exc.code,
                                      exc.read().decode("utf-8", "replace")[:400]))
            messages.pop()
            continue
        except Exception as exc:  # noqa: BLE001
            print("\n[ERROR] %s" % exc)
            messages.pop()
            continue

        line = stats_line(usage, timings, elapsed, ttft, len(reasoning))
        if line:
            print("\n" + line)
            last = (usage, timings, elapsed, ttft, line)
        print()
        if answer:
            messages.append({"role": "assistant", "content": answer})
        else:
            print("(empty answer — try /think off or a larger /max)")
            messages.pop()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
