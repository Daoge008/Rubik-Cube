"""OpenSSH ProxyCommand: tunnel a TCP connection through an HTTP CONNECT proxy.

Why this exists
---------------
On a machine whose proxy runs in fake-IP mode (Clash and friends), `github.com`
resolves into the 198.18.0.0/15 range and port 22 is handled by the proxy rather
than reached directly. OpenSSH has no native HTTP-proxy support, and a plain
PortableGit install ships neither `connect.exe` nor `nc` for the classic
`ProxyCommand nc -X connect` trick, so `git@github.com:...` fails with:

    Connection closed by 198.18.0.160 port 22

HTTPS on 443 works fine, but it is not a way out if you have no stored HTTPS
credential -- note that `git ls-remote` over HTTPS succeeding proves nothing,
because reading a public repo needs no authentication at all while pushing
always does.

The way that does work is GitHub's own SSH-over-HTTPS endpoint,
`ssh.github.com:443`: it serves the same host key and the same account as
`github.com`, and -- unlike upstream port 22 -- the proxy actually forwards it.
See `push.bat` next to this file for the wiring.

Measured on the machine this was written for (CONNECT issued straight to the
proxy, nothing else in the path):

    github.com:22       -> 200 Connection Established, then NO banner  <- fake success
    ssh.github.com:443  -> 200 Connection Established, then SSH-2.0-... OK
    github.com:443      -> 200 Connection Established, then waits for ClientHello

The first line is the trap: a 200 only means the proxy accepted the request, not
that the far end is reachable, so ssh reports a closed connection and you go
looking for the problem in your keys.

Usage
-----
This is meant to be used as an OpenSSH ProxyCommand, not run by hand:

    ssh -o "ProxyCommand=<python> connect_tunnel.py %h %p" git@ssh.github.com

`push.bat` sets that up. The proxy address comes from TUNNEL_PROXY, falling back
to https_proxy / http_proxy, and the scheme prefix is optional
(`http://127.0.0.1:8080` and `127.0.0.1:8080` both work).
"""

import os
import socket
import sys
import threading

DEFAULT_PROXY_ENV = ("TUNNEL_PROXY", "https_proxy", "HTTPS_PROXY", "http_proxy", "HTTP_PROXY")


def die(msg: str) -> "None":
    # Write straight to fd 2 and exit hard. A normal `raise SystemExit` would run
    # interpreter finalization while the stdin pump thread still holds the
    # buffered-reader lock, and CPython then aborts with
    # "_enter_buffered_busy ... at interpreter shutdown" -- which buries the very
    # error we are trying to report.
    try:
        os.write(2, ("[connect_tunnel] " + msg + "\n").encode("utf-8", "replace"))
    except OSError:
        pass
    os._exit(1)


def resolve_proxy() -> str:
    for name in DEFAULT_PROXY_ENV:
        raw = os.environ.get(name)
        if not raw:
            continue
        value = raw.strip()
        # Strip a scheme, if any: we only speak plain HTTP CONNECT here.
        if "://" in value:
            scheme, _, value = value.partition("://")
            if scheme.lower() != "http":
                die(f"{name}={raw!r} uses an unsupported scheme; expected http://")
        value = value.rstrip("/")
        if value.count(":") != 1:
            die(f"{name}={raw!r} is not host:port")
        return value
    die(
        "no proxy configured. Set TUNNEL_PROXY (or https_proxy) to host:port, e.g. "
        "set TUNNEL_PROXY=127.0.0.1:7890"
    )


def pump_in(sock: socket.socket) -> None:
    """stdin -> socket, then half-close so the peer sees EOF."""
    try:
        while True:
            chunk = sys.stdin.buffer.read1(65536)
            if not chunk:
                break
            sock.sendall(chunk)
    except (OSError, ValueError):
        pass
    finally:
        try:
            sock.shutdown(socket.SHUT_WR)
        except OSError:
            pass


def main() -> None:
    if len(sys.argv) < 3:
        die("usage: connect_tunnel.py <host> <port>")

    host, port = sys.argv[1], int(sys.argv[2])
    proxy_host, proxy_port = resolve_proxy().rsplit(":", 1)

    try:
        sock = socket.create_connection((proxy_host, int(proxy_port)), timeout=30)
    except OSError as exc:
        die(f"cannot reach proxy {proxy_host}:{proxy_port}: {exc}")

    sock.settimeout(30)
    sock.sendall(
        f"CONNECT {host}:{port} HTTP/1.1\r\nHost: {host}:{port}\r\n\r\n".encode("ascii")
    )

    # Read only up to the end of the response headers; whatever follows is
    # already target traffic and must be forwarded, not swallowed.
    buf = b""
    while b"\r\n\r\n" not in buf:
        try:
            chunk = sock.recv(4096)
        except OSError as exc:
            die(f"proxy read failed: {exc}")
        if not chunk:
            die("proxy closed the connection during CONNECT")
        buf += chunk

    head, _, rest = buf.partition(b"\r\n\r\n")
    status = head.split(b"\r\n", 1)[0]
    if b" 200" not in status:
        die(f"CONNECT refused: {status.decode('latin-1')}")

    sock.settimeout(None)

    if rest:
        sys.stdout.buffer.write(rest)
        sys.stdout.buffer.flush()

    threading.Thread(target=pump_in, args=(sock,), daemon=True).start()

    try:
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            sys.stdout.buffer.write(chunk)
            sys.stdout.buffer.flush()
    except OSError:
        pass

    # Same reason as in die(): skip finalization so the still-running stdin pump
    # thread cannot abort the interpreter on its way out.
    os._exit(0)


if __name__ == "__main__":
    main()
