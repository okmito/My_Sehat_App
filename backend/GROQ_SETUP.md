# Setting Up GROQ API Key for Mental Health Backend

## What is GROQ?
GROQ is a fast AI inference platform with competitive pricing. The mental health backend uses GROQ's LLM API for AI-powered responses.

## Where to Get GROQ API Key

### Step 1: Create GROQ Account
1. Go to https://console.groq.com/keys
2. Sign up for a free account (or sign in if you have one)
3. Verify your email

### Step 2: Generate API Key
1. After signing in, go to **API Keys** section
2. Click **Create API Key**
3. Copy the key (you won't see it again, so save it securely)

### Step 3: Set Environment Variable

#### **Windows (PowerShell)**
```powershell
$env:GROQ_API_KEY = "your-api-key-here"

# Verify it's set
echo $env:GROQ_API_KEY

# Then start backends
python start_all_backends.py
```

#### **Windows (Command Prompt)**
```cmd
set GROQ_API_KEY=your-api-key-here

# Verify it's set
echo %GROQ_API_KEY%

# Then start backends
python start_all_backends.py
```

#### **Windows (Permanent - System Variable)**
1. Press `Win + X` → Choose **System**
2. Go to **Advanced system settings**
3. Click **Environment Variables**
4. Under **User variables**, click **New**
   - Variable name: `GROQ_API_KEY`
   - Variable value: `your-api-key-here`
5. Click **OK** and restart PowerShell/CMD

#### **macOS/Linux**
```bash
export GROQ_API_KEY="your-api-key-here"

# Verify it's set
echo $GROQ_API_KEY

# Then start backends
python start_all_backends.py
```

#### **macOS/Linux (Permanent)**
Add to `~/.bash_profile` or `~/.zshrc`:
```bash
export GROQ_API_KEY="your-api-key-here"
```

Then reload:
```bash
source ~/.bash_profile
# or
source ~/.zshrc
```

## Free Tier Limits
- **Requests**: 30 per minute
- **Cost**: FREE tier available
- **Models**: llama2-70b, mixtral-8x7b, etc.

## Verify Setup

Run this to verify the key is set:

**PowerShell:**
```powershell
if ($env:GROQ_API_KEY) { "✅ API Key is set" } else { "❌ API Key not set" }
```

**Bash:**
```bash
if [ -z "$GROQ_API_KEY" ]; then echo "❌ API Key not set"; else echo "✅ API Key is set"; fi
```

## Testing the Setup

After setting the API key:

```powershell
# In backend directory
python start_all_backends.py
```

Check for success:
```
✅ Backends started successfully!
Uvicorn running on http://0.0.0.0:8003
```

If mental health fails, you'll see:
```
❌ Error: openai.OpenAIError: The api_key client option must be set...
```

## Optional: Use .env File

Create `.env` file in `backend/`:

```
GROQ_API_KEY=your-api-key-here
```

Then modify `start_all_backends.py` to load it:

```python
from dotenv import load_dotenv
load_dotenv()
```

And install python-dotenv:
```bash
pip install python-dotenv
```

## Troubleshooting

### "API Key not valid"
- Verify you copied the key correctly from https://console.groq.com/keys
- Keys are case-sensitive

### "Rate limit exceeded"
- You've hit the 30 requests/minute limit
- Wait a minute and try again
- Consider upgrading to paid tier

### Still getting import errors
- Make sure Python environment is activated: `.venv\Scripts\Activate.ps1`
- Reinstall packages: `pip install -r requirements.txt`

## Security Note ⚠️

**Never commit API keys to git!**

- Add `.env` to `.gitignore`
- Use environment variables instead
- Regenerate key if accidentally exposed

## Next Steps

Once API key is set up:
```powershell
python start_all_backends.py
```

All 4 backends should now start without errors! ✅
