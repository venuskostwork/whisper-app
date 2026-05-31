# whisper — special voice notes

> *Leave a voice, they'll turn to hear.*

A minimal voice note keepsake app. Record or upload audio, share a link, and the recipient turns a handle — like a music box — to listen.

Built with vanilla HTML/CSS/JS + Supabase (Auth, Database, Storage).

---

## What's in this folder

| File | Purpose |
|---|---|
| `whisper_supabase.html` | The complete app — rename to `index.html` before deploying |
| `supabase_setup.sql` | Run once in Supabase SQL Editor to create all tables + policies |
| `vercel.json` | Vercel config (SPA routing) |
| `.env.example` | Template for your Supabase credentials |
| `README.md` | This file |

---

## Setup — step by step

### Step 1 — Supabase project

1. Go to [supabase.com](https://supabase.com) → New project
2. Pick a region close to your users (Singapore for Indonesia)
3. Save your database password somewhere safe

### Step 2 — Create the Storage bucket

1. In Supabase dashboard → **Storage** → **New bucket**
2. Name: `whisper-audio`
3. Toggle **Public** → ON
4. Click Create

### Step 3 — Run the SQL migration

1. In Supabase dashboard → **SQL Editor** → **New query**
2. Copy the entire contents of `supabase_setup.sql`
3. Paste and click **Run**
4. You should see: "Success. No rows returned"

### Step 4 — Get your Supabase credentials

In Supabase dashboard → **Settings** → **API**:

- **Project URL** → copy the URL (looks like `https://xxxxxxxxxxxx.supabase.co`)
- **Project API keys** → copy the `anon` / `public` key

### Step 5 — Add credentials to the HTML file

Open `whisper_supabase.html` and find these two lines near the top of the `<script>` block:

```js
const SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';
const SUPABASE_KEY = 'YOUR_ANON_PUBLIC_KEY';
```

Replace with your actual values. Save the file.

### Step 6 — Deploy to Vercel

1. Rename `whisper_supabase.html` → `index.html`
2. Create a new GitHub repository (e.g. `whisper-app`)
3. Upload `index.html` and `vercel.json` to the repo
4. Go to [vercel.com](https://vercel.com) → **New Project** → Import the repo
5. Framework preset: **Other**
6. Click **Deploy**

Done — your app is live.

---

## How it works

### For the creator (logged in)
1. Sign up / sign in with email + password
2. Create a folder (private or unlisted)
3. Add a whisper — upload audio or record directly, add a title and optional message
4. Get a shareable link

### For the listener (no login needed)
1. Open the link
2. Turn the handle clockwise to hear the voice
3. The faster you turn, the faster it plays
4. Stop turning → audio pauses

---

## Database schema

### `profiles`
| Column | Type | Notes |
|---|---|---|
| id | uuid | FK → auth.users |
| display_name | text | shown in nav |
| email | text | |
| created_at | timestamptz | |

### `folders`
| Column | Type | Notes |
|---|---|---|
| id | uuid | primary key |
| user_id | uuid | FK → auth.users |
| name | text | |
| visibility | text | `private` or `unlisted` |
| description | text | optional |
| created_at | timestamptz | |

### `whispers`
| Column | Type | Notes |
|---|---|---|
| id | uuid | primary key |
| user_id | uuid | FK → auth.users |
| folder_id | uuid | FK → folders |
| title | text | |
| for_whom | text | optional |
| message | text | optional written note |
| audio_url | text | public CDN URL |
| audio_path | text | storage path for deletion |
| duration | float | seconds |
| share_token | text | unique 8-char slug |
| created_at | timestamptz | |

---

## Storage

Audio files are stored in the `whisper-audio` bucket under:
```
whisper-audio/{user_id}/{random_id}.{ext}
```

- Supported formats: MP3, WAV, M4A, OGG, WEBM
- Max file size: 50MB per file
- Supabase free plan: 1GB total storage
- Files are publicly readable (required for the listen page — no auth needed)
- Only the owner can upload or delete their own files (enforced by RLS)

---

## Security

- **Row Level Security (RLS)** is enabled on all tables
- Users can only modify their own folders and whispers
- Whispers are publicly readable by design — the `share_token` acts as the access key
- Audio files follow the same model — public URL, but only owners can upload/delete
- Passwords are handled entirely by Supabase Auth (bcrypt hashed, never stored in plain text)

---

## Supabase free plan limits

| Resource | Free limit | Notes |
|---|---|---|
| Database | 500MB | More than enough for metadata |
| Storage | 1GB | ~500–1000 audio files depending on length |
| Auth users | Unlimited | |
| API requests | 500K/month | Very generous for personal use |
| Bandwidth | 5GB/month | Audio streaming counts toward this |

---

## Customization

### Change the app name / branding
Search for `whisper` and `senaslowblog` in the HTML and replace as needed.

### Change audio file size limit
Find this line in the script:
```js
if(file.size > 50*1024*1024)
```
Change `50` to your preferred MB limit.

### Change DPS (playback speed per rotation)
```js
const DPS = 260;
```
Higher number = more rotation needed per second of audio (slower feel).
Lower number = less rotation per second (faster feel).

### Add email confirmation on signup
In Supabase dashboard → **Authentication** → **Email** → toggle **Confirm email** ON.
Users will need to verify their email before they can log in.

---

## Troubleshooting

**"Upload failed" when saving a whisper**
- Check that the `whisper-audio` bucket exists and is set to Public
- Check that you ran the full SQL migration (storage policies are at the bottom)
- Make sure your Supabase URL and key are correct in the HTML

**Audio doesn't play on the listen page**
- The bucket must be Public for audio URLs to work without auth
- Check browser console for CORS errors
- Supabase Storage automatically handles CORS for public buckets

**"this whisper does not exist" on a valid link**
- The share token in the URL must match exactly
- Check that RLS policy `whispers: public read` was created successfully
- Run in SQL Editor: `select * from whispers limit 5;` to confirm data exists

**Can't sign in after registering**
- If email confirmation is ON in Supabase Auth settings, user must confirm email first
- Check Supabase dashboard → Authentication → Users to see if the user exists

---

## Roadmap (future ideas)

- [ ] Whisper expiry (auto-delete after N days)
- [ ] Play count tracking
- [ ] Password-protected whispers
- [ ] Multiple audio tracks per folder (playlist mode)
- [ ] Reaction / emoji response from listener
- [ ] Admin panel with feature flags (whisper on/off, enable/disable)

---

*whisper — by senaslowblog*
