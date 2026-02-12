import sqlite3
from typing import List, Optional, Dict, Any
import json
from datetime import datetime
import os

# Detect Render environment and use appropriate database path
render_env = os.environ.get("RENDER", None)
if render_env or os.environ.get("PORT"):
    # On Render, use /tmp for writable storage
    DB_NAME = "/tmp/app.db"
else:
    # Local development
    DB_NAME = "app.db"

def get_db_connection():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Initialize database tables with error handling."""
    print("[INFO] Initializing Mental Health Backend database...")
    try:
        conn = get_db_connection()
        c = conn.cursor()
        
        # Messages table
        c.execute('''
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                role TEXT NOT NULL,
                text TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
        ''')

        # Risk Events table
        c.execute('''
            CREATE TABLE IF NOT EXISTS risk_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                message_id INTEGER,
                risk_level TEXT NOT NULL,
                self_harm_detected BOOLEAN NOT NULL,
                keyword_score INTEGER,
                reasons_json TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY(message_id) REFERENCES messages(id)
            )
        ''')

        # Daily Summary table
        c.execute('''
            CREATE TABLE IF NOT EXISTS daily_summaries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                date TEXT NOT NULL,
                summary_text TEXT,
                risk_level TEXT,
                created_at TEXT NOT NULL
            )
        ''')
        
        conn.commit()
        conn.close()
        
        print(f"[OK] Mental Health database tables created successfully at: {DB_NAME}")
        print("[OK] Available Mental Health tables: messages, risk_events, daily_summaries")
    except Exception as e:
        print(f"[ERROR] Failed to create Mental Health database tables: {e}")
        raise

# Helper functions for persistence

def save_message(user_id: str, role: str, text: str) -> int:
    conn = get_db_connection()
    c = conn.cursor()
    created_at = datetime.utcnow().isoformat()
    c.execute(
        "INSERT INTO messages (user_id, role, text, created_at) VALUES (?, ?, ?, ?)",
        (user_id, role, text, created_at)
    )
    msg_id = c.lastrowid
    conn.commit()
    conn.close()
    return msg_id

def save_risk_event(user_id: str, message_id: Optional[int], risk_level: str, self_harm_detected: bool, keyword_score: int, reasons: List[str]):
    conn = get_db_connection()
    c = conn.cursor()
    created_at = datetime.utcnow().isoformat()
    reasons_json = json.dumps(reasons)
    c.execute(
        '''INSERT INTO risk_events 
           (user_id, message_id, risk_level, self_harm_detected, keyword_score, reasons_json, created_at) 
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        (user_id, message_id, risk_level, int(self_harm_detected), keyword_score, reasons_json, created_at)
    )
    conn.commit()
    conn.close()

def save_daily_summary(user_id: str, date: str, summary_text: str, risk_level: str):
    conn = get_db_connection()
    c = conn.cursor()
    created_at = datetime.utcnow().isoformat()
    c.execute(
        '''INSERT INTO daily_summaries 
           (user_id, date, summary_text, risk_level, created_at) 
           VALUES (?, ?, ?, ?, ?)''',
        (user_id, date, summary_text, risk_level, created_at)
    )
    conn.commit()
    conn.close()

def get_daily_summary(user_id: str, date: str):
    conn = get_db_connection()
    c = conn.cursor()
    c.execute("SELECT * FROM daily_summaries WHERE user_id = ? AND date = ?", (user_id, date))
    row = c.fetchone()
    conn.close()
    if row:
        return dict(row)
    return None

def get_recent_messages(user_id: str, limit: int = 10) -> List[Dict[str, Any]]:
    """Get recent messages for conversation context."""
    conn = get_db_connection()
    c = conn.cursor()
    c.execute(
        "SELECT role, text FROM messages WHERE user_id = ? ORDER BY id DESC LIMIT ?",
        (user_id, limit)
    )
    rows = c.fetchall()
    conn.close()
    # Reverse to get chronological order
    return [{"role": row["role"], "content": row["text"]} for row in reversed(rows)]


# ============================================================================
# DPDP COMPLIANCE FUNCTIONS
# ============================================================================

def save_user_preferences(user_id: str, preferences: Dict[str, Any]):
    """Save user's DPDP preferences."""
    conn = get_db_connection()
    c = conn.cursor()
    
    # Ensure table exists
    c.execute('''
        CREATE TABLE IF NOT EXISTS user_preferences (
            user_id TEXT PRIMARY KEY,
            session_only BOOLEAN DEFAULT 0,
            allow_storage BOOLEAN DEFAULT 1,
            consent_id INTEGER,
            updated_at TEXT NOT NULL
        )
    ''')
    
    updated_at = datetime.utcnow().isoformat()
    c.execute('''
        INSERT OR REPLACE INTO user_preferences 
        (user_id, session_only, allow_storage, consent_id, updated_at)
        VALUES (?, ?, ?, ?, ?)
    ''', (
        user_id,
        int(preferences.get("session_only", False)),
        int(preferences.get("allow_storage", True)),
        preferences.get("consent_id"),
        updated_at
    ))
    conn.commit()
    conn.close()


def get_user_preferences(user_id: str) -> Optional[Dict[str, Any]]:
    """Get user's DPDP preferences."""
    conn = get_db_connection()
    c = conn.cursor()
    
    # Ensure table exists
    c.execute('''
        CREATE TABLE IF NOT EXISTS user_preferences (
            user_id TEXT PRIMARY KEY,
            session_only BOOLEAN DEFAULT 0,
            allow_storage BOOLEAN DEFAULT 1,
            consent_id INTEGER,
            updated_at TEXT NOT NULL
        )
    ''')
    conn.commit()
    
    c.execute("SELECT * FROM user_preferences WHERE user_id = ?", (user_id,))
    row = c.fetchone()
    conn.close()
    
    if row:
        return {
            "session_only": bool(row["session_only"]),
            "allow_storage": bool(row["allow_storage"]),
            "consent_id": row["consent_id"]
        }
    return None


def get_all_messages(user_id: str) -> List[Dict[str, Any]]:
    """Get all messages for a user (data export)."""
    conn = get_db_connection()
    c = conn.cursor()
    c.execute(
        "SELECT id, role, text, created_at FROM messages WHERE user_id = ? ORDER BY id",
        (user_id,)
    )
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]


def get_all_risk_events(user_id: str) -> List[Dict[str, Any]]:
    """Get all risk events for a user (data export)."""
    conn = get_db_connection()
    c = conn.cursor()
    c.execute(
        "SELECT * FROM risk_events WHERE user_id = ? ORDER BY id",
        (user_id,)
    )
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]


def get_all_daily_summaries(user_id: str) -> List[Dict[str, Any]]:
    """Get all daily summaries for a user (data export)."""
    conn = get_db_connection()
    c = conn.cursor()
    c.execute(
        "SELECT * FROM daily_summaries WHERE user_id = ? ORDER BY date",
        (user_id,)
    )
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]


def delete_all_user_data(anon_user_id: str, real_user_id: str) -> int:
    """
    Delete all user data (Right to Erasure).
    Returns count of deleted records.
    """
    conn = get_db_connection()
    c = conn.cursor()
    
    deleted = 0
    
    # Delete messages (using anonymous ID)
    c.execute("DELETE FROM messages WHERE user_id = ?", (anon_user_id,))
    deleted += c.rowcount
    
    # Delete risk events (using anonymous ID)
    c.execute("DELETE FROM risk_events WHERE user_id = ?", (anon_user_id,))
    deleted += c.rowcount
    
    # Delete daily summaries (using anonymous ID)
    c.execute("DELETE FROM daily_summaries WHERE user_id = ?", (anon_user_id,))
    deleted += c.rowcount
    
    # Delete preferences (using real user ID)
    c.execute("DELETE FROM user_preferences WHERE user_id = ?", (real_user_id,))
    deleted += c.rowcount
    
    conn.commit()
    conn.close()
    
    return deleted
