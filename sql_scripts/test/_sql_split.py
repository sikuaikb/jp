"""Extract helpers without running sync on import."""
import re


def split_statements(sql: str):
    stmts = []
    buf = []
    i = 0
    n = len(sql)
    in_squote = False
    in_dquote = False
    in_line_comment = False
    in_block_comment = False
    while i < n:
        ch = sql[i]
        nxt = sql[i + 1] if i + 1 < n else ""
        if in_line_comment:
            buf.append(ch)
            if ch == "\n":
                in_line_comment = False
            i += 1
            continue
        if in_block_comment:
            buf.append(ch)
            if ch == "*" and nxt == "/":
                buf.append(nxt)
                i += 2
                in_block_comment = False
                continue
            i += 1
            continue
        if not in_squote and not in_dquote:
            if ch == "-" and nxt == "-":
                buf.append(ch)
                buf.append(nxt)
                i += 2
                in_line_comment = True
                continue
            if ch == "/" and nxt == "*":
                buf.append(ch)
                buf.append(nxt)
                i += 2
                in_block_comment = True
                continue
            if ch == ";":
                stmt = "".join(buf).strip()
                if stmt:
                    stmts.append(stmt)
                buf = []
                i += 1
                continue
        if ch == "'" and not in_dquote:
            if in_squote and nxt == "'":
                buf.append(ch)
                buf.append(nxt)
                i += 2
                continue
            in_squote = not in_squote
        elif ch == '"' and not in_squote:
            in_dquote = not in_dquote
        buf.append(ch)
        i += 1
    tail = "".join(buf).strip()
    if tail:
        stmts.append(tail)
    return stmts


def nonempty_bodies(stmts):
    out = []
    for idx, stmt in enumerate(stmts, 1):
        body = re.sub(r"/\*.*?\*/", "", stmt, flags=re.S)
        body = re.sub(r"--.*?$", "", body, flags=re.M).strip()
        if body:
            out.append((idx, stmt, body))
    return out
