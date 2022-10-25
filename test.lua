local s = "commit f3299c0764896688b1e34d5785f257c4b29c90f7 (HEAD -> master, origin/master, origin/HEAD)"

print(s:match("([| *]*)%*?commit (%w+)"))
