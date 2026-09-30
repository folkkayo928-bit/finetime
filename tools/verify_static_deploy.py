from pathlib import Path
import sys
root=Path("build/web")
required=["index.html","partner/index.html","partner.html","website/index.html","website/news.html","admin/index.html"]
missing=[p for p in required if not (root/p).exists()]
bad=[]
for p in required:
    if (root/p).exists():
        t=(root/p).read_text(encoding="utf-8")
        if "__SUPABASE_URL__" in t or "__SUPABASE_ANON_KEY__" in t: bad.append("unresolved config: "+p)
        if "SUPABASE_SERVICE_ROLE_KEY" in t or "FINETIME_TELEGRAM_BOT_TOKEN" in t: bad.append("private secret reference: "+p)
if missing or bad:
    print("missing:",missing,"bad:",bad);sys.exit(1)
print("Static deployment package verification passed.")
