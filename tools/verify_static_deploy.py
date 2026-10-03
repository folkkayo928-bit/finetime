from pathlib import Path
import re
import subprocess
import sys
import tempfile

root=Path("build/web")
required=["index.html","flutter_bootstrap.js","finetime/index.html","finetime/flutter_bootstrap.js","partner/index.html","partner.html","website/index.html","website/news.html","website/business.html","admin/index.html"]
missing=[p for p in required if not (root/p).exists()]
bad=[]
for p in required:
    if (root/p).exists():
        t=(root/p).read_text(encoding="utf-8")
        if "__SUPABASE_URL__" in t or "__SUPABASE_ANON_KEY__" in t: bad.append("unresolved config: "+p)
        if p in ("index.html","finetime/index.html") and "flutter_bootstrap.js" not in t: bad.append("Flutter bootstrap script missing from "+p)
        if p == "website/index.html" and 'href="/finetime/"' not in t: bad.append("public website has no Launch/Open App root link")
        if p in ("flutter_bootstrap.js","finetime/flutter_bootstrap.js") and "serviceWorkerSettings" in t: bad.append("legacy Flutter service worker bootstrap still enabled: "+p)
        if "SUPABASE_SERVICE_ROLE_KEY" in t or "FINETIME_TELEGRAM_BOT_TOKEN" in t: bad.append("private secret reference: "+p)
        if "cdn.jsdelivr.net/npm/@supabase/supabase-js" in t or "window.supabase" in t: bad.append("browser Supabase SDK dependency: "+p)
        scripts=re.findall(r"<script(?:\s[^>]*)?>(.*?)</script>",t,re.S|re.I)
        for i,script in enumerate(scripts):
            if not script.strip(): continue
            with tempfile.NamedTemporaryFile("w",suffix=".js",encoding="utf-8",delete=False) as fh:
                fh.write(script)
                temp=fh.name
            try:
                check=subprocess.run(["node","--check",temp],text=True,capture_output=True)
                if check.returncode:
                    bad.append(f"JavaScript syntax error: {p} script {i+1}: {check.stderr.strip()}")
            finally:
                Path(temp).unlink(missing_ok=True)
if missing or bad:
    print("missing:",missing,"bad:",bad);sys.exit(1)
print("Static deployment package verification passed.")
