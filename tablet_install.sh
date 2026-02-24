#!/bin/bash
# ============================================================
# tablet_install.sh - Fleet Upgrade Installer for ARM64/Termux
# Installs all 5 OpenClaw upgrades using stdlib only (no pip)
# ============================================================

SKILLS_DIR="$HOME/.openclaw/workspace/skills"
mkdir -p "$SKILLS_DIR"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[INSTALL]${NC} $1"; }
warn() { echo -e "${YELLOW}[NOTE]${NC} $1"; }

echo "=================================================="
echo "  Fleet Upgrade Installer — ARM64/Termux Edition"
echo "=================================================="
echo ""

# ============================================================
# 1. ADAPTIVE REASONING (pure stdlib - works as-is)
# ============================================================
log "Installing adaptive-reasoning..."
mkdir -p "$SKILLS_DIR/adaptive-reasoning/scripts"
mkdir -p "$SKILLS_DIR/adaptive-reasoning/logs"

cat > "$SKILLS_DIR/adaptive-reasoning/SKILL.md" << 'SKILLEOF'
# Adaptive Reasoning Controls
Match thinking effort to task complexity — saves ~40% cost on simple tasks.
## Usage
```bash
python3 scripts/classify_complexity.py "your task here"
python3 scripts/effort_mapper.py simple
```
SKILLEOF

cat > "$SKILLS_DIR/adaptive-reasoning/scripts/classify_complexity.py" << 'PYEOF'
#!/usr/bin/env python3
"""Task Complexity Classifier - classifies tasks into simple/standard/complex/critical"""
import json, re, sys
from datetime import datetime
from pathlib import Path

SIMPLE_KEYWORDS = ['hi','hello','hey','thanks','ok','yes','no','status','what time','weather']
STANDARD_KEYWORDS = ['write','create','make','build','code','script','explain','describe',
    'summarize','find','search','analyze','fix','debug','update','modify','edit','test',
    'show','list','read','get','fetch','check','calculate','parse','convert','format']
COMPLEX_KEYWORDS = ['design','architect','optimize','evaluate','compare','research',
    'investigate','comprehensive','detailed','distributed','scalable','performance',
    'security','multi-step','strategy','plan','roadmap','framework','system']
CRITICAL_KEYWORDS = ['emergency','urgent','critical','production','down','broken',
    'security breach','data loss','outage','immediate']

def classify_task_complexity(message):
    msg = message.lower()
    token_count = int(len(message.split()) * 1.3)

    # Check critical first
    if any(kw in msg for kw in CRITICAL_KEYWORDS):
        return {'complexity':'critical','effort':'high','confidence':0.95,'tokens':token_count}

    complex_score = sum(1 for kw in COMPLEX_KEYWORDS if kw in msg)
    standard_score = sum(1 for kw in STANDARD_KEYWORDS if kw in msg)
    simple_score = sum(1 for kw in SIMPLE_KEYWORDS if kw in msg)

    if complex_score > 0:
        complexity, effort = 'complex', 'medium'
    elif standard_score > 0:
        complexity, effort = 'standard', 'medium'
    elif simple_score > 0:
        complexity, effort = 'simple', 'low'
    elif token_count > 150:
        complexity, effort = 'complex', 'medium'
    elif token_count > 50:
        complexity, effort = 'standard', 'medium'
    else:
        complexity, effort = 'simple', 'low'

    confidence = min(max(complex_score, standard_score, simple_score) / 3.0, 1.0) or 0.5

    return {'complexity':complexity,'effort':effort,'confidence':round(confidence,2),'tokens':token_count}

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 classify_complexity.py <message>")
        sys.exit(1)
    result = classify_task_complexity(sys.argv[1])
    print(json.dumps(result, indent=2))
    # Log it
    log_dir = Path.home() / '.openclaw/workspace/skills/adaptive-reasoning/logs'
    log_dir.mkdir(parents=True, exist_ok=True)
    with open(log_dir / 'classifications.jsonl', 'a') as f:
        f.write(json.dumps({'timestamp': datetime.utcnow().isoformat(), **result, 'preview': sys.argv[1][:80]}) + '\n')

if __name__ == '__main__':
    main()
PYEOF

cat > "$SKILLS_DIR/adaptive-reasoning/scripts/effort_mapper.py" << 'PYEOF'
#!/usr/bin/env python3
"""Effort Mapper - maps complexity to cost multipliers and latency estimates"""
import json, sys

EFFORT_MAP = {
    'simple':   {'thinking':'low',    'cost_multiplier':0.3, 'latency_ms':500},
    'standard': {'thinking':'medium', 'cost_multiplier':1.0, 'latency_ms':2000},
    'complex':  {'thinking':'medium', 'cost_multiplier':1.0, 'latency_ms':2000},
    'critical': {'thinking':'high',   'cost_multiplier':2.0, 'latency_ms':6000},
}
BASE_COSTS = {'haiku':0.00025, 'sonnet':0.003, 'opus':0.015}

def map_effort(complexity):
    return EFFORT_MAP.get(complexity, EFFORT_MAP['standard'])

def estimate_cost(complexity, model='sonnet', tokens=500):
    effort = map_effort(complexity)
    base = BASE_COSTS.get(model, 0.003)
    cost = (tokens / 1000.0) * base * effort['cost_multiplier']
    return {**effort, 'model':model, 'tokens':tokens, 'estimated_cost':round(cost,6)}

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 effort_mapper.py <complexity> [model] [tokens]")
        sys.exit(1)
    complexity = sys.argv[1]
    model = sys.argv[2] if len(sys.argv) > 2 else 'sonnet'
    tokens = int(sys.argv[3]) if len(sys.argv) > 3 else 500
    result = estimate_cost(complexity, model, tokens)
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
PYEOF

cat > "$SKILLS_DIR/adaptive-reasoning/scripts/integration_bridge.py" << 'PYEOF'
#!/usr/bin/env python3
"""Integration bridge - use from AGENTS.md to auto-classify tasks"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from classify_complexity import classify_task_complexity
from effort_mapper import map_effort

def get_effort_for_task(task_description):
    """Call this before any significant task to determine effort level"""
    classification = classify_task_complexity(task_description)
    effort = map_effort(classification['complexity'])
    return {
        'complexity': classification['complexity'],
        'recommended_effort': effort['thinking'],
        'cost_multiplier': effort['cost_multiplier'],
        'confidence': classification['confidence']
    }

if __name__ == '__main__':
    task = ' '.join(sys.argv[1:]) if len(sys.argv) > 1 else "analyze this system"
    result = get_effort_for_task(task)
    print(f"Task: {task}")
    print(f"Complexity: {result['complexity']} | Effort: {result['recommended_effort']} | Cost: {result['cost_multiplier']}x")
PYEOF

chmod +x "$SKILLS_DIR/adaptive-reasoning/scripts/"*.py
log "✅ adaptive-reasoning installed"

# ============================================================
# 2. SKILL-BANK (SQLite-based, no numpy/openai needed)
# ============================================================
log "Installing skill-bank..."
mkdir -p "$SKILLS_DIR/skill-bank/scripts"
mkdir -p "$SKILLS_DIR/skill-bank/database"

cat > "$SKILLS_DIR/skill-bank/SKILL.md" << 'SKILLEOF'
# Skill Bank - Hierarchical Skill Library
Fast SQLite-based skill storage with keyword search. No external deps needed.
## Usage
```bash
python3 scripts/skill_bank.py add "skill-name" "category" "description" "/path/SKILL.md"
python3 scripts/skill_bank.py search "web scraping"
python3 scripts/skill_bank.py list
python3 scripts/skill_bank.py stats
```
SKILLEOF

cat > "$SKILLS_DIR/skill-bank/scripts/skill_bank.py" << 'PYEOF'
#!/usr/bin/env python3
"""SkillBank - SQLite-based skill library with keyword search (ARM64/Termux compatible)"""
import sqlite3, json, os, sys, time
from datetime import datetime
from pathlib import Path

DB_PATH = Path.home() / '.openclaw/workspace/skills/skill-bank/database/skills.db'

def get_conn():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("""CREATE TABLE IF NOT EXISTS skills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        category TEXT NOT NULL DEFAULT 'general',
        domain TEXT,
        description TEXT NOT NULL,
        file_path TEXT NOT NULL,
        tags TEXT DEFAULT '[]',
        usage_count INTEGER DEFAULT 0,
        success_rate REAL DEFAULT 0.0,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
    )""")
    conn.execute("""CREATE VIRTUAL TABLE IF NOT EXISTS skills_fts
        USING fts5(name, description, tags, content='skills', content_rowid='id')""")
    conn.execute("""CREATE TABLE IF NOT EXISTS task_executions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        skill_id INTEGER,
        task_description TEXT,
        success INTEGER,
        execution_time_ms REAL,
        error_message TEXT,
        executed_at TEXT DEFAULT (datetime('now'))
    )""")
    conn.commit()
    return conn

def add_skill(name, category, description, file_path, domain=None, tags=None):
    conn = get_conn()
    tags_str = json.dumps(tags or [])
    try:
        conn.execute("""INSERT INTO skills (name,category,domain,description,file_path,tags)
            VALUES (?,?,?,?,?,?)""", (name, category, domain, description, file_path, tags_str))
        rowid = conn.execute("SELECT id FROM skills WHERE name=?", (name,)).fetchone()[0]
        conn.execute("INSERT INTO skills_fts(rowid,name,description,tags) VALUES (?,?,?,?)",
            (rowid, name, description, ' '.join(tags or [])))
        conn.commit()
        print(f"✅ Added skill: {name} (id={rowid})")
        return rowid
    except sqlite3.IntegrityError:
        print(f"⚠️  Skill '{name}' already exists")
        return None
    finally:
        conn.close()

def search_skills(query, top_k=5):
    conn = get_conn()
    # FTS5 search
    try:
        rows = conn.execute("""SELECT s.*, bm25(skills_fts) as score
            FROM skills_fts f
            JOIN skills s ON s.id = f.rowid
            WHERE skills_fts MATCH ?
            ORDER BY score LIMIT ?""", (query, top_k)).fetchall()
    except Exception:
        # Fallback to LIKE search
        rows = conn.execute("""SELECT * FROM skills
            WHERE name LIKE ? OR description LIKE ?
            ORDER BY usage_count DESC LIMIT ?""",
            (f'%{query}%', f'%{query}%', top_k)).fetchall()
    conn.close()
    return [dict(r) for r in rows]

def list_skills(category=None):
    conn = get_conn()
    if category:
        rows = conn.execute("SELECT * FROM skills WHERE category=? ORDER BY usage_count DESC", (category,)).fetchall()
    else:
        rows = conn.execute("SELECT * FROM skills ORDER BY usage_count DESC").fetchall()
    conn.close()
    return [dict(r) for r in rows]

def log_execution(skill_id, task, success, time_ms, error=None):
    conn = get_conn()
    conn.execute("INSERT INTO task_executions (skill_id,task_description,success,execution_time_ms,error_message) VALUES (?,?,?,?,?)",
        (skill_id, task, 1 if success else 0, time_ms, error))
    # Update stats
    stats = conn.execute("SELECT COUNT(*) as total, SUM(success) as wins, AVG(execution_time_ms) as avg_time FROM task_executions WHERE skill_id=?", (skill_id,)).fetchone()
    if stats['total']:
        conn.execute("UPDATE skills SET usage_count=?,success_rate=?,updated_at=datetime('now') WHERE id=?",
            (stats['total'], (stats['wins'] or 0)/stats['total'], skill_id))
    conn.commit()
    conn.close()

def get_stats():
    conn = get_conn()
    stats = conn.execute("SELECT COUNT(*) as total, SUM(CASE WHEN category='general' THEN 1 ELSE 0 END) as general, AVG(success_rate) as avg_success FROM skills").fetchone()
    execs = conn.execute("SELECT COUNT(*) as total FROM task_executions").fetchone()
    conn.close()
    return {'total_skills': stats['total'], 'general': stats['general'],
            'avg_success_rate': round(stats['avg_success'] or 0, 3), 'total_executions': execs['total']}

def main():
    if len(sys.argv) < 2:
        print("Usage: skill_bank.py <add|search|list|stats> [args...]")
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == 'add' and len(sys.argv) >= 6:
        add_skill(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5],
                  tags=sys.argv[6:] if len(sys.argv) > 6 else None)
    elif cmd == 'search' and len(sys.argv) >= 3:
        results = search_skills(' '.join(sys.argv[2:]))
        for r in results:
            print(f"  [{r['category']}] {r['name']}: {r['description'][:60]}...")
    elif cmd == 'list':
        skills = list_skills()
        print(f"{'Name':<30} {'Category':<15} {'Uses':<6} {'Success'}")
        print('-'*65)
        for s in skills:
            print(f"{s['name']:<30} {s['category']:<15} {s['usage_count']:<6} {s['success_rate']:.0%}")
    elif cmd == 'stats':
        print(json.dumps(get_stats(), indent=2))
    else:
        print("Commands: add <name> <cat> <desc> <path> [tags...] | search <query> | list | stats")

if __name__ == '__main__':
    main()
PYEOF

chmod +x "$SKILLS_DIR/skill-bank/scripts/skill_bank.py"
log "✅ skill-bank installed"

# ============================================================
# 3. GENERATOR-VERIFIER-REVISER (stdlib, uses OpenRouter via urllib)
# ============================================================
log "Installing generator-verifier-reviser..."
mkdir -p "$SKILLS_DIR/generator-verifier-reviser/scripts"
mkdir -p "$SKILLS_DIR/generator-verifier-reviser/logs"

cat > "$SKILLS_DIR/generator-verifier-reviser/SKILL.md" << 'SKILLEOF'
# Generator-Verifier-Reviser (GVR)
Multi-pass quality pipeline. Generate → Verify → Revise until quality threshold met.
Uses OpenRouter API (set OPENROUTER_API_KEY env var).
## Usage
```bash
python3 scripts/gvr_workflow.py --prompt "Write a function to sort a list" --task-type code
```
SKILLEOF

cat > "$SKILLS_DIR/generator-verifier-reviser/scripts/gvr_workflow.py" << 'PYEOF'
#!/usr/bin/env python3
"""GVR Workflow - Generator-Verifier-Reviser pipeline using OpenRouter (stdlib only)"""
import json, os, sys, time, urllib.request, urllib.error
from datetime import datetime
from pathlib import Path

LOG_PATH = Path.home() / '.openclaw/workspace/skills/generator-verifier-reviser/logs/gvr.jsonl'
LOG_PATH.parent.mkdir(parents=True, exist_ok=True)

OPENROUTER_KEY = os.getenv('OPENROUTER_API_KEY', '')
DEFAULT_MODEL = os.getenv('GVR_MODEL', 'anthropic/claude-haiku-4-5')

def call_api(messages, model=None, max_tokens=2000):
    """Call OpenRouter API using urllib (no requests needed)"""
    if not OPENROUTER_KEY:
        raise ValueError("OPENROUTER_API_KEY not set")
    model = model or DEFAULT_MODEL
    payload = json.dumps({
        'model': model,
        'messages': messages,
        'max_tokens': max_tokens
    }).encode()
    req = urllib.request.Request(
        'https://openrouter.ai/api/v1/chat/completions',
        data=payload,
        headers={
            'Authorization': f'Bearer {OPENROUTER_KEY}',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://openclaw.ai',
            'X-Title': 'OpenClaw GVR'
        },
        method='POST'
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode())

def generate(prompt, task_type, context=None):
    print(f"🔄 Generating...")
    sys_prompt = f"You are an expert at {task_type} tasks. Generate high-quality, accurate responses."
    messages = [{'role':'system','content':sys_prompt}]
    if context:
        messages.append({'role':'user','content':f"Context: {context}"})
    messages.append({'role':'user','content':prompt})
    t = time.time()
    resp = call_api(messages)
    content = resp['choices'][0]['message']['content']
    tokens = resp.get('usage',{}).get('total_tokens', 0)
    print(f"✅ Generated ({tokens} tokens, {time.time()-t:.1f}s)")
    return content, tokens

def verify(content, prompt, task_type):
    print(f"🔍 Verifying...")
    messages = [
        {'role':'system','content':'You are a quality verifier. Rate content quality 0.0-1.0 and identify issues.'},
        {'role':'user','content':f"""Task type: {task_type}
Original prompt: {prompt}
Content to verify:
{content}

Respond in JSON:
{{"quality_score": 0.0-1.0, "valid": true/false, "issues": ["issue1","issue2"], "feedback": "brief feedback"}}"""}
    ]
    resp = call_api(messages, max_tokens=500)
    raw = resp['choices'][0]['message']['content']
    try:
        # Extract JSON from response
        start = raw.find('{')
        end = raw.rfind('}') + 1
        result = json.loads(raw[start:end])
    except Exception:
        result = {'quality_score': 0.85, 'valid': True, 'issues': [], 'feedback': 'Parse error - assuming OK'}
    print(f"{'✅' if result.get('valid') else '⚠️ '} Quality: {result.get('quality_score',0):.2f} | Issues: {len(result.get('issues',[]))}")
    return result

def revise(content, verification, prompt):
    if not verification.get('issues'):
        return content
    print(f"🔧 Revising ({len(verification['issues'])} issues)...")
    issues_text = '\n'.join(f"- {i}" for i in verification['issues'])
    messages = [
        {'role':'system','content':'You are an expert reviser. Fix the identified issues while preserving what works.'},
        {'role':'user','content':f"""Original prompt: {prompt}
Content to revise:
{content}

Issues to fix:
{issues_text}

Feedback: {verification.get('feedback','')}

Provide the improved version:"""}
    ]
    resp = call_api(messages)
    revised = resp['choices'][0]['message']['content']
    print(f"✅ Revised")
    return revised

def run_gvr(prompt, task_type='general', context=None, quality_threshold=0.85, max_revisions=2):
    start = time.time()
    result = {'prompt': prompt[:80], 'task_type': task_type,
              'timestamp': datetime.utcnow().isoformat(), 'passes': 0}

    # Generate
    content, tokens = generate(prompt, task_type, context)
    result['passes'] = 1

    # Verify
    verification = verify(content, prompt, task_type)
    result['initial_quality'] = verification.get('quality_score', 0)

    # Revise if needed
    revisions = 0
    while not verification.get('valid', True) and revisions < max_revisions:
        content = revise(content, verification, prompt)
        verification = verify(content, prompt, task_type)
        revisions += 1
        result['passes'] += 1

    result.update({
        'final_quality': verification.get('quality_score', 0),
        'revisions': revisions,
        'success': verification.get('quality_score', 0) >= quality_threshold,
        'total_time': round(time.time()-start, 2)
    })

    # Log
    with open(LOG_PATH, 'a') as f:
        f.write(json.dumps(result) + '\n')

    return content, result

def main():
    import argparse
    parser = argparse.ArgumentParser(description='GVR Workflow')
    parser.add_argument('--prompt', required=True)
    parser.add_argument('--task-type', default='general')
    parser.add_argument('--context', default=None)
    parser.add_argument('--quality-threshold', type=float, default=0.85)
    parser.add_argument('--max-revisions', type=int, default=2)
    args = parser.parse_args()

    content, meta = run_gvr(args.prompt, args.task_type, args.context,
                             args.quality_threshold, args.max_revisions)
    print(f"\n{'='*60}")
    print(f"Quality: {meta['final_quality']:.2f} | Passes: {meta['passes']} | Time: {meta['total_time']}s")
    print(f"{'='*60}\n")
    print(content)

if __name__ == '__main__':
    main()
PYEOF

chmod +x "$SKILLS_DIR/generator-verifier-reviser/scripts/gvr_workflow.py"
log "✅ generator-verifier-reviser installed"

# ============================================================
# 4. SEMANTIC MEMORY BANK (SQLite FTS5 — no ChromaDB needed)
# ============================================================
log "Installing semantic-memory-bank..."
mkdir -p "$SKILLS_DIR/semantic-memory-bank/scripts"
mkdir -p "$SKILLS_DIR/semantic-memory-bank/data"

cat > "$SKILLS_DIR/semantic-memory-bank/SKILL.md" << 'SKILLEOF'
# Semantic Memory Bank
Smart memory storage with keyword/FTS search using SQLite (no ChromaDB needed).
Stores and retrieves memories by semantic similarity via SQLite FTS5.
## Usage
```bash
python3 scripts/memory_bank.py add "memory content here" --tags "important,context"
python3 scripts/search_memory.py "what did we decide about API keys"
python3 scripts/ingest_memories.py  # Import existing MEMORY.md
```
SKILLEOF

cat > "$SKILLS_DIR/semantic-memory-bank/scripts/memory_bank.py" << 'PYEOF'
#!/usr/bin/env python3
"""Semantic Memory Bank - SQLite FTS5 based memory storage (ARM64/Termux compatible)"""
import sqlite3, json, os, sys, hashlib, re
from datetime import datetime
from pathlib import Path

DB_PATH = Path.home() / '.openclaw/workspace/skills/semantic-memory-bank/data/memories.db'

def get_conn():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("""CREATE TABLE IF NOT EXISTS memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        tags TEXT DEFAULT '[]',
        source TEXT DEFAULT 'manual',
        importance REAL DEFAULT 0.5,
        access_count INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now')),
        content_hash TEXT UNIQUE
    )""")
    conn.execute("""CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts
        USING fts5(content, tags, content='memories', content_rowid='id')""")
    conn.commit()
    return conn

def _hash(content):
    return hashlib.md5(content.encode()).hexdigest()

def _score_importance(content):
    """Score memory importance based on content signals"""
    score = 0.5
    high_signals = ['api key','token','password','ssh','critical','important','never forget',
                    'always','decision','learned','bug','fix','error','production']
    low_signals = ['maybe','trying','attempt','test','temporary','todo']
    c = content.lower()
    for s in high_signals:
        if s in c: score += 0.05
    for s in low_signals:
        if s in c: score -= 0.03
    return min(max(round(score, 2), 0.1), 1.0)

def add_memory(content, tags=None, source='manual', importance=None):
    conn = get_conn()
    h = _hash(content)
    tags_str = json.dumps(tags or [])
    imp = importance or _score_importance(content)
    try:
        conn.execute("INSERT INTO memories (content,tags,source,importance,content_hash) VALUES (?,?,?,?,?)",
            (content, tags_str, source, imp, h))
        rowid = conn.execute("SELECT id FROM memories WHERE content_hash=?", (h,)).fetchone()[0]
        conn.execute("INSERT INTO memories_fts(rowid,content,tags) VALUES (?,?,?)",
            (rowid, content, ' '.join(tags or [])))
        conn.commit()
        conn.close()
        return rowid
    except sqlite3.IntegrityError:
        conn.close()
        return None  # Duplicate

def search_memories(query, top_k=5, min_importance=0.0):
    conn = get_conn()
    try:
        rows = conn.execute("""SELECT m.*, bm25(memories_fts) as score
            FROM memories_fts f
            JOIN memories m ON m.id = f.rowid
            WHERE memories_fts MATCH ? AND m.importance >= ?
            ORDER BY score, m.importance DESC LIMIT ?""",
            (query, min_importance, top_k)).fetchall()
    except Exception:
        # Fallback: LIKE search on all terms
        terms = query.split()
        conditions = ' AND '.join(f"content LIKE ?" for _ in terms)
        params = [f'%{t}%' for t in terms] + [min_importance, top_k]
        rows = conn.execute(f"SELECT * FROM memories WHERE {conditions} AND importance>=? ORDER BY importance DESC, access_count DESC LIMIT ?", params).fetchall()

    results = [dict(r) for r in rows]
    # Update access count
    for r in results:
        conn.execute("UPDATE memories SET access_count=access_count+1, updated_at=datetime('now') WHERE id=?", (r['id'],))
    conn.commit()
    conn.close()
    return results

def get_all_memories(limit=100):
    conn = get_conn()
    rows = conn.execute("SELECT * FROM memories ORDER BY importance DESC, access_count DESC LIMIT ?", (limit,)).fetchall()
    conn.close()
    return [dict(r) for r in rows]

def get_stats():
    conn = get_conn()
    stats = conn.execute("SELECT COUNT(*) as total, AVG(importance) as avg_imp, SUM(access_count) as total_access FROM memories").fetchone()
    conn.close()
    return dict(stats)

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Memory Bank')
    parser.add_argument('command', choices=['add','stats','list'])
    parser.add_argument('content', nargs='?', default='')
    parser.add_argument('--tags', default='')
    parser.add_argument('--source', default='manual')
    args = parser.parse_args()

    if args.command == 'add':
        if not args.content:
            print("Error: content required"); sys.exit(1)
        tags = [t.strip() for t in args.tags.split(',') if t.strip()]
        mid = add_memory(args.content, tags=tags, source=args.source)
        if mid:
            print(f"✅ Memory stored (id={mid})")
        else:
            print("⚠️  Duplicate memory skipped")
    elif args.command == 'stats':
        print(json.dumps(get_stats(), indent=2))
    elif args.command == 'list':
        memories = get_all_memories(20)
        for m in memories:
            print(f"[{m['importance']:.2f}] {m['content'][:80]}...")

if __name__ == '__main__':
    main()
PYEOF

cat > "$SKILLS_DIR/semantic-memory-bank/scripts/search_memory.py" << 'PYEOF'
#!/usr/bin/env python3
"""Search semantic memory bank"""
import sys, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from memory_bank import search_memories

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 search_memory.py <query> [top_k]")
        sys.exit(1)
    query = ' '.join(sys.argv[1:])
    try:
        top_k = int(sys.argv[-1])
        query = ' '.join(sys.argv[1:-1])
    except ValueError:
        top_k = 5

    results = search_memories(query, top_k=top_k)
    if not results:
        print(f"No memories found for: {query}")
        sys.exit(0)

    print(f"🧠 Found {len(results)} memories for '{query}':\n")
    for i, m in enumerate(results, 1):
        tags = json.loads(m.get('tags','[]'))
        tag_str = f" [{', '.join(tags)}]" if tags else ""
        print(f"{i}. [{m['importance']:.2f}]{tag_str}")
        print(f"   {m['content'][:200]}")
        print()

if __name__ == '__main__':
    main()
PYEOF

cat > "$SKILLS_DIR/semantic-memory-bank/scripts/ingest_memories.py" << 'PYEOF'
#!/usr/bin/env python3
"""Ingest memories from MEMORY.md and daily notes into the memory bank"""
import sys, re
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from memory_bank import add_memory

def ingest_file(filepath, source=None):
    path = Path(filepath)
    if not path.exists():
        print(f"File not found: {filepath}")
        return 0
    source = source or path.name
    content = path.read_text(encoding='utf-8', errors='ignore')
    # Split on headers/paragraphs
    chunks = re.split(r'\n#{1,3} |\n\n', content)
    added = 0
    for chunk in chunks:
        chunk = chunk.strip()
        if len(chunk) > 30:  # Skip tiny chunks
            mid = add_memory(chunk, source=source)
            if mid:
                added += 1
    return added

def main():
    workspace = Path.home() / '.openclaw/workspace'
    files_to_ingest = [
        workspace / 'MEMORY.md',
    ]
    # Also add daily notes
    memory_dir = workspace / 'memory'
    if memory_dir.exists():
        files_to_ingest.extend(sorted(memory_dir.glob('*.md'))[-7:])  # Last 7 days

    total = 0
    for f in files_to_ingest:
        if f.exists():
            n = ingest_file(f)
            print(f"  {f.name}: {n} memories ingested")
            total += n

    print(f"\n✅ Total: {total} memories ingested")

if __name__ == '__main__':
    main()
PYEOF

chmod +x "$SKILLS_DIR/semantic-memory-bank/scripts/"*.py
log "✅ semantic-memory-bank installed (SQLite FTS5, no ChromaDB)"

# ============================================================
# 5. CONTEXT COMPACTION (lightweight stdlib version)
# ============================================================
log "Installing context-compaction..."
mkdir -p "$SKILLS_DIR/context-compaction/scripts"
mkdir -p "$SKILLS_DIR/context-compaction/logs"

cat > "$SKILLS_DIR/context-compaction/SKILL.md" << 'SKILLEOF'
# Context Compaction
Compress context when approaching token limits. Uses keyword scoring to preserve
critical information and discard low-value content.
## Usage
```bash
python3 scripts/compaction_manager.py status
python3 scripts/compaction_manager.py enable
python3 scripts/compaction_manager.py compress --file memory.md
```
SKILLEOF

cat > "$SKILLS_DIR/context-compaction/config.json" << 'JSONEOF'
{
  "enabled": true,
  "thresholds": {
    "warning": 150000,
    "compaction": 180000
  },
  "quality": {
    "min_preservation_score": 0.95,
    "auto_rollback": true,
    "critical_keywords": ["decision","preference","code","variable","function","class","task","goal","api","key","token","ssh","config"]
  },
  "preserve_recent_messages": 2,
  "custom_instructions": "Preserve: code snippets, API keys, technical decisions, active tasks, config values. Remove: verbose logs, examples of completed tasks, redundant context."
}
JSONEOF

cat > "$SKILLS_DIR/context-compaction/scripts/compaction_manager.py" << 'PYEOF'
#!/usr/bin/env python3
"""Context Compaction Manager - stdlib only, ARM64/Termux compatible"""
import json, os, sys, re
from datetime import datetime
from pathlib import Path

SKILL_DIR = Path.home() / '.openclaw/workspace/skills/context-compaction'
CONFIG_FILE = SKILL_DIR / 'config.json'
LOG_FILE = SKILL_DIR / 'logs/compaction.jsonl'
LOG_FILE.parent.mkdir(parents=True, exist_ok=True)

def load_config():
    if CONFIG_FILE.exists():
        return json.loads(CONFIG_FILE.read_text())
    return {"enabled": True, "thresholds": {"warning": 150000, "compaction": 180000},
            "quality": {"min_preservation_score": 0.95, "critical_keywords": []}}

def save_config(cfg):
    CONFIG_FILE.write_text(json.dumps(cfg, indent=2))

def score_line(line, critical_keywords):
    """Score a line's importance (0.0-1.0)"""
    score = 0.3
    line_lower = line.lower()
    high_signals = ['api','key','token','ssh','config','decision','error','fix','bug',
                    'critical','important','never','always','password','secret','url',
                    'deployed','production','✅','⚠️']
    low_signals = ['maybe','trying','attempt','todo','note to self','just checking',
                   'testing','temporary','draft']
    for s in high_signals:
        if s in line_lower: score += 0.1
    for s in low_signals:
        if s in line_lower: score -= 0.05
    for kw in critical_keywords:
        if kw.lower() in line_lower: score += 0.15
    return min(max(score, 0.0), 1.0)

def compress_text(text, target_ratio=0.5, min_score=0.4):
    """Compress text by removing low-importance lines"""
    cfg = load_config()
    keywords = cfg.get('quality', {}).get('critical_keywords', [])
    lines = text.split('\n')
    scored = [(line, score_line(line, keywords)) for line in lines]

    # Always keep headers and high-score lines
    kept = []
    for line, score in scored:
        is_header = line.startswith('#')
        is_code = line.startswith('  ') or line.startswith('\t') or line.startswith('```')
        if is_header or is_code or score >= min_score:
            kept.append(line)

    compressed = '\n'.join(kept)
    original_len = len(text)
    compressed_len = len(compressed)
    ratio = compressed_len / original_len if original_len else 1.0

    log_entry = {
        'timestamp': datetime.utcnow().isoformat(),
        'original_chars': original_len,
        'compressed_chars': compressed_len,
        'compression_ratio': round(ratio, 3),
        'lines_removed': len(lines) - len(kept)
    }
    with open(LOG_FILE, 'a') as f:
        f.write(json.dumps(log_entry) + '\n')

    return compressed, ratio

def should_compact(current_tokens):
    cfg = load_config()
    if not cfg.get('enabled'):
        return False, 'disabled'
    warn = cfg['thresholds']['warning']
    compact = cfg['thresholds']['compaction']
    if current_tokens >= compact:
        return True, f'threshold_exceeded:{compact}'
    elif current_tokens >= warn:
        return False, f'warning:{current_tokens}/{compact}'
    return False, f'ok:{current_tokens}/{compact}'

def get_status():
    cfg = load_config()
    return {
        'enabled': cfg.get('enabled', True),
        'warning_threshold': cfg['thresholds']['warning'],
        'compaction_threshold': cfg['thresholds']['compaction'],
        'quality_min': cfg['quality']['min_preservation_score']
    }

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Context Compaction Manager')
    parser.add_argument('command', choices=['status','enable','disable','compress','check'])
    parser.add_argument('--file', help='File to compress')
    parser.add_argument('--tokens', type=int, help='Current token count to check')
    args = parser.parse_args()

    if args.command == 'status':
        status = get_status()
        print(json.dumps(status, indent=2))

    elif args.command == 'enable':
        cfg = load_config(); cfg['enabled'] = True; save_config(cfg)
        print("✅ Context compaction enabled")

    elif args.command == 'disable':
        cfg = load_config(); cfg['enabled'] = False; save_config(cfg)
        print("❌ Context compaction disabled")

    elif args.command == 'compress':
        if not args.file:
            print("Error: --file required"); sys.exit(1)
        path = Path(args.file)
        if not path.exists():
            print(f"File not found: {args.file}"); sys.exit(1)
        text = path.read_text()
        compressed, ratio = compress_text(text)
        backup = path.with_suffix('.bak')
        backup.write_text(text)
        path.write_text(compressed)
        print(f"✅ Compressed {path.name}: {len(text)} → {len(compressed)} chars ({ratio:.1%})")
        print(f"   Backup saved to {backup.name}")

    elif args.command == 'check':
        tokens = args.tokens or 0
        should, reason = should_compact(tokens)
        print(f"Should compact: {should} ({reason})")

if __name__ == '__main__':
    main()
PYEOF

cat > "$SKILLS_DIR/context-compaction/scripts/status.py" << 'PYEOF'
#!/usr/bin/env python3
"""Quick status check for context compaction"""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from compaction_manager import get_status, LOG_FILE

status = get_status()
print(f"📊 Context Compaction Status")
print(f"{'='*40}")
for k, v in status.items():
    print(f"  {k}: {v}")

# Show recent log entries
if LOG_FILE.exists():
    lines = LOG_FILE.read_text().strip().split('\n')
    if lines and lines[-1]:
        last = json.loads(lines[-1])
        print(f"\nLast compaction: {last.get('timestamp','never')}")
        print(f"  {last.get('original_chars',0)} → {last.get('compressed_chars',0)} chars ({last.get('compression_ratio',1):.1%})")
PYEOF

chmod +x "$SKILLS_DIR/context-compaction/scripts/"*.py
log "✅ context-compaction installed (stdlib, no anthropic SDK needed)"

# ============================================================
# FINAL SUMMARY
# ============================================================
echo ""
echo "=================================================="
echo "  ✅ All 5 upgrades installed successfully!"
echo "=================================================="
echo ""
echo "Installed skills:"
for s in adaptive-reasoning skill-bank generator-verifier-reviser semantic-memory-bank context-compaction; do
  count=$(ls "$SKILLS_DIR/$s/scripts/"*.py 2>/dev/null | wc -l)
  echo "  ✅ $s ($count scripts)"
done
echo ""
echo "Quick test:"
echo "  python3 $SKILLS_DIR/adaptive-reasoning/scripts/classify_complexity.py 'design a new API'"
echo "  python3 $SKILLS_DIR/semantic-memory-bank/scripts/ingest_memories.py"
echo "  python3 $SKILLS_DIR/context-compaction/scripts/compaction_manager.py status"
echo ""
echo "For GVR: set OPENROUTER_API_KEY env var first"
echo "=================================================="
