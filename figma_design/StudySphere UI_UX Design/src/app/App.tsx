import { useState, useRef, useEffect } from "react";
import {
  Home, FileText, Users, Bot, User, Search, Bell,
  ChevronRight, Download, Heart, MessageCircle, Send,
  Filter, BookOpen, Paperclip,
} from "lucide-react";

// ── DATA ───────────────────────────────────────────────────────────────────────

const COURSES = [
  { id: 1, title: "Flutter Development", sub: "12 lessons", bg: "#4A90D9", icon: "F",  progress: 65 },
  { id: 2, title: "JavaScript Basics",   sub: "8 lessons",  bg: "#E8A020", icon: "JS", progress: 40 },
  { id: 3, title: "Python Flask",        sub: "15 lessons", bg: "#3BAD6A", icon: "Py", progress: 25 },
];

const NOTES_DATA = [
  { id: 1, title: "Topic Development",   subject: "Operating System",  tag: "BTECH", tagColor: "#7C72E8", time: "1 day"  },
  { id: 2, title: "Topic Development",   subject: "Computer Networks", tag: "BCOM",  tagColor: "#3B82F6", time: "3 days" },
  { id: 3, title: "Database Management", subject: "DBMS Concepts",    tag: "BTECH", tagColor: "#22C55E", time: "4 days" },
  { id: 4, title: "Operating System",    subject: "Process Management",tag: "BSC",   tagColor: "#F97316", time: "5 days" },
  { id: 5, title: "Web Development",     subject: "HTML, CSS & JS",   tag: "BTECH", tagColor: "#06B6D4", time: "5 days" },
];

const POSTS = [
  { id: 1, name: "Priya Patel",  init: "PP", color: "#E91E8C", time: "2h ago",  content: "DBMS is such a great subject! Can anyone share notes on normalization concepts? Would really appreciate! 📚", likes: 24, comments: 8,  liked: false },
  { id: 2, name: "Ananya Joshi", init: "AJ", color: "#7C72E8", time: "4h ago",  content: "Just finished my Operating Systems assignment. The concept of deadlock avoidance using Banker's algorithm is fascinating! 🎯", likes: 18, comments: 12, liked: false },
  { id: 3, name: "Rahul Verma",  init: "RV", color: "#F97316", time: "6h ago",  content: "Looking for study partners for Data Structures. Anyone interested in group study sessions? Let's ace this together! 🤝", likes: 31, comments: 15, liked: true  },
];

const INIT_MSGS = [
  { id: 1, role: "ai",   text: "Explain the concept of Object Oriented Programming in Java." },
  { id: 2, role: "user", text: "Object Oriented Programming (OOP) in Java is a programming paradigm based on the concept of \"objects\".\n\nKey principles:\n\n• Encapsulation — bundling data with methods\n• Abstraction — hiding complex implementation\n• Inheritance — extending parent class features\n• Polymorphism — one interface, many forms" },
];

const NOTE_FILTERS = ["All", "BTECH", "BCOM", "BSC"];

// ── AVATAR ILLUSTRATION ────────────────────────────────────────────────────────

function HeroAvatar() {
  return (
    <svg viewBox="0 0 110 148" fill="none" xmlns="http://www.w3.org/2000/svg" style={{ height: "100%", width: "auto" }}>
      {/* Hair back volume */}
      <ellipse cx="55" cy="60" rx="36" ry="40" fill="#2D1B0E" />
      {/* Curly top puffs */}
      <ellipse cx="55" cy="26" rx="24" ry="22" fill="#3D2010" />
      <ellipse cx="32" cy="34" rx="17" ry="19" fill="#3D2010" />
      <ellipse cx="78" cy="34" rx="17" ry="19" fill="#3D2010" />
      <ellipse cx="42" cy="18" rx="13" ry="13" fill="#2D1B0E" />
      <ellipse cx="68" cy="18" rx="13" ry="13" fill="#2D1B0E" />
      {/* Face */}
      <ellipse cx="55" cy="68" rx="27" ry="28" fill="#FDBCB4" />
      {/* Eyebrows */}
      <path d="M 42 61 Q 46 59 50 61" stroke="#2D1B0E" strokeWidth="1.8" strokeLinecap="round" fill="none" />
      <path d="M 60 61 Q 64 59 68 61" stroke="#2D1B0E" strokeWidth="1.8" strokeLinecap="round" fill="none" />
      {/* Eyes */}
      <ellipse cx="46" cy="65" rx="3.8" ry="4.2" fill="#1A0A00" />
      <ellipse cx="64" cy="65" rx="3.8" ry="4.2" fill="#1A0A00" />
      <circle cx="47.5" cy="63.5" r="1.3" fill="white" />
      <circle cx="65.5" cy="63.5" r="1.3" fill="white" />
      {/* Smile */}
      <path d="M 47 76 Q 55 84 63 76" stroke="#D4896A" strokeWidth="2" fill="none" strokeLinecap="round" />
      {/* Cheek blush */}
      <ellipse cx="38" cy="72" rx="5.5" ry="3" fill="#FFB3A7" opacity="0.55" />
      <ellipse cx="72" cy="72" rx="5.5" ry="3" fill="#FFB3A7" opacity="0.55" />
      {/* Neck */}
      <rect x="48" y="92" width="14" height="12" rx="4" fill="#FDBCB4" />
      {/* Hoodie body */}
      <path d="M 8 125 Q 8 100 55 100 Q 102 100 102 125 L 110 150 L 0 150 Z" fill="#FF9800" />
      {/* Hood center */}
      <path d="M 37 100 Q 55 112 73 100 L 68 118 Q 55 124 42 118 Z" fill="#E08500" />
      {/* Left sleeve */}
      <path d="M 8 125 Q -2 118 2 134 Q 6 142 18 137 L 22 120 Z" fill="#FF9800" />
      {/* Right sleeve */}
      <path d="M 102 125 Q 112 118 108 134 Q 104 142 92 137 L 88 120 Z" fill="#FF9800" />
      {/* Hands */}
      <ellipse cx="5"   cy="135" rx="7" ry="5" fill="#FDBCB4" transform="rotate(-25 5 135)" />
      <ellipse cx="105" cy="135" rx="7" ry="5" fill="#FDBCB4" transform="rotate(25 105 135)" />
    </svg>
  );
}

// ── BOTTOM NAV ─────────────────────────────────────────────────────────────────

const TABS = [
  { id: "home",      label: "Home",      Icon: Home     },
  { id: "notes",     label: "Notes",     Icon: FileText },
  { id: "community", label: "Community", Icon: Users    },
  { id: "ai",        label: "AI",        Icon: Bot      },
  { id: "profile",   label: "Profile",   Icon: User     },
];

function BottomNav({ active, onChange }: { active: string; onChange: (t: string) => void }) {
  return (
    <div className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-[390px] bg-white border-t border-border z-40" style={{ boxShadow: "0 -4px 20px rgba(124,114,232,0.08)" }}>
      <div className="flex items-stretch">
        {TABS.map(({ id, label, Icon }) => {
          const on = active === id;
          return (
            <button key={id} onClick={() => onChange(id)} className="flex-1 flex flex-col items-center justify-center py-2.5 gap-0.5 transition-all">
              <div className={`w-10 h-8 flex items-center justify-center rounded-xl transition-all ${on ? "bg-[#EEECff]" : ""}`}>
                <Icon size={20} style={{ color: on ? "#7C72E8" : "#9B9ABD" }} strokeWidth={on ? 2.5 : 1.8} />
              </div>
              <span className="text-[10px] font-medium" style={{ color: on ? "#7C72E8" : "#9B9ABD" }}>{label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

// ── HOME SCREEN ────────────────────────────────────────────────────────────────

function HomeScreen({ goNotes, goCommunity, goAI }: { goNotes: () => void; goCommunity: () => void; goAI: () => void }) {
  return (
    <div className="overflow-y-auto pb-24 h-full" style={{ scrollbarWidth: "none" }}>
      {/* App bar */}
      <div className="flex items-center justify-between px-5 pt-12 pb-4">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-xl flex items-center justify-center" style={{ background: "linear-gradient(135deg, #7C72E8, #A99EF5)" }}>
            <BookOpen size={15} color="white" strokeWidth={2.5} />
          </div>
          <span className="text-base font-bold text-foreground" style={{ fontFamily: "'Outfit', sans-serif" }}>StudySphere</span>
        </div>
        <button className="relative w-9 h-9 rounded-xl bg-white flex items-center justify-center border border-border">
          <Bell size={17} color="#7C72E8" />
          <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-[#E91E8C]" />
        </button>
      </div>

      {/* Hero card */}
      <div className="mx-5 rounded-3xl overflow-hidden relative" style={{ background: "linear-gradient(135deg, #7B72E9 0%, #9F97F2 60%, #B8B2FF 100%)", height: "160px" }}>
        {/* Decorative circles */}
        <div className="absolute -right-6 -top-6 w-40 h-40 rounded-full opacity-20" style={{ background: "rgba(255,255,255,0.3)" }} />
        <div className="absolute right-8 bottom-4 w-20 h-20 rounded-full opacity-15" style={{ background: "rgba(255,255,255,0.4)" }} />
        {/* Text */}
        <div className="absolute left-5 top-5 right-28">
          <p className="text-white text-xl font-bold leading-snug" style={{ fontFamily: "'Outfit', sans-serif" }}>Hello, Omkar! 👋</p>
          <p className="text-white/80 text-xs mt-1.5 leading-relaxed">Let's continue your learning journey today!</p>
        </div>
        {/* Avatar */}
        <div className="absolute bottom-0 right-3" style={{ height: "148px" }}>
          <HeroAvatar />
        </div>
      </div>

      {/* Search bar */}
      <div className="mx-5 mt-4">
        <div className="flex items-center gap-3 bg-white rounded-2xl px-4 py-3 border border-border" style={{ boxShadow: "0 2px 12px rgba(124,114,232,0.08)" }}>
          <Search size={17} color="#9B9ABD" />
          <span className="text-sm text-muted-foreground">Search papers, subjects...</span>
        </div>
      </div>

      {/* Feature grid */}
      <div className="px-5 mt-6 grid grid-cols-2 gap-3">
        {[
          { label: "Notes",          sub: "Study smarter",  bg: "#7C72E8", Icon: FileText,  action: goNotes     },
          { label: "Question Papers",sub: "Past exams",     bg: "#FF8C42", Icon: BookOpen,  action: () => {}    },
          { label: "Community",      sub: "Ask & answer",  bg: "#E91E8C", Icon: Users,     action: goCommunity },
          { label: "AI Assistant",   sub: "Learn faster",  bg: "#3B82F6", Icon: Bot,       action: goAI        },
        ].map(({ label, sub, bg, Icon, action }) => (
          <button
            key={label}
            onClick={action}
            className="rounded-3xl p-4 flex flex-col items-start text-left transition-all active:scale-95"
            style={{ background: bg, minHeight: "120px" }}
          >
            <div className="w-11 h-11 rounded-2xl flex items-center justify-center mb-3" style={{ background: "rgba(255,255,255,0.22)" }}>
              <Icon size={22} color="white" strokeWidth={1.8} />
            </div>
            <p className="text-white font-bold text-sm leading-tight" style={{ fontFamily: "'Outfit', sans-serif" }}>{label}</p>
            <p className="text-white/75 text-xs mt-0.5">{sub}</p>
          </button>
        ))}
      </div>

      {/* Continue Learning */}
      <div className="mt-6">
        <div className="px-5 flex items-center justify-between mb-3">
          <p className="font-bold text-foreground text-base" style={{ fontFamily: "'Outfit', sans-serif" }}>Continue Learning</p>
          <button className="text-xs font-semibold" style={{ color: "#7C72E8" }}>See all</button>
        </div>
        <div className="flex gap-3 px-5 overflow-x-auto pb-1" style={{ scrollbarWidth: "none" }}>
          {COURSES.map((c) => (
            <div key={c.id} className="shrink-0 rounded-3xl overflow-hidden" style={{ width: "152px", background: c.bg }}>
              <div className="p-4">
                {/* Icon area */}
                <div className="w-12 h-12 rounded-2xl mb-3 flex items-center justify-center font-black text-lg" style={{ background: "rgba(255,255,255,0.25)", color: "white", fontFamily: "monospace" }}>
                  {c.icon}
                </div>
                <p className="text-white font-bold text-sm leading-tight" style={{ fontFamily: "'Outfit', sans-serif" }}>{c.title}</p>
                <p className="text-white/75 text-xs mt-0.5">{c.sub}</p>
                {/* Progress */}
                <div className="mt-3">
                  <div className="h-1.5 rounded-full" style={{ background: "rgba(255,255,255,0.25)" }}>
                    <div className="h-full rounded-full bg-white" style={{ width: `${c.progress}%` }} />
                  </div>
                  <p className="text-white/75 text-[10px] mt-1">{c.progress}% complete</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Recent Activity */}
      <div className="mt-6 px-5">
        <div className="flex items-center justify-between mb-3">
          <p className="font-bold text-foreground text-base" style={{ fontFamily: "'Outfit', sans-serif" }}>Recent Activity</p>
          <button className="text-xs font-semibold" style={{ color: "#7C72E8" }}>See all</button>
        </div>
        <div className="bg-white rounded-2xl border border-border p-4 flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0" style={{ background: "#FFF0E8" }}>
            <Paperclip size={18} color="#FF8C42" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold text-foreground truncate">Data Structures Notes.pdf</p>
            <p className="text-xs text-muted-foreground mt-0.5">2.4 MB · Saved yesterday</p>
          </div>
          <button className="w-8 h-8 rounded-xl flex items-center justify-center shrink-0" style={{ background: "#F3F2FF" }}>
            <Download size={14} color="#7C72E8" />
          </button>
        </div>
        <div className="bg-white rounded-2xl border border-border p-4 flex items-center gap-3 mt-2">
          <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0" style={{ background: "#EEF0FF" }}>
            <FileText size={18} color="#7C72E8" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold text-foreground truncate">Operating Systems - Unit 3.pdf</p>
            <p className="text-xs text-muted-foreground mt-0.5">1.8 MB · Saved 2 days ago</p>
          </div>
          <button className="w-8 h-8 rounded-xl flex items-center justify-center shrink-0" style={{ background: "#F3F2FF" }}>
            <Download size={14} color="#7C72E8" />
          </button>
        </div>
      </div>

      <div className="h-4" />
    </div>
  );
}

// ── NOTES SCREEN ───────────────────────────────────────────────────────────────

function NotesScreen() {
  const [filter, setFilter] = useState("All");
  const filtered = filter === "All" ? NOTES_DATA : NOTES_DATA.filter((n) => n.tag === filter);

  return (
    <div className="overflow-y-auto pb-24 h-full" style={{ scrollbarWidth: "none" }}>
      {/* Header */}
      <div className="px-5 pt-12 pb-4 flex items-center justify-between">
        <p className="text-xl font-bold text-foreground" style={{ fontFamily: "'Outfit', sans-serif" }}>Notes</p>
        <button className="w-9 h-9 rounded-xl flex items-center justify-center border border-border bg-white">
          <Filter size={16} color="#7C72E8" />
        </button>
      </div>

      {/* Filter tabs */}
      <div className="flex gap-2 px-5 mb-5">
        {NOTE_FILTERS.map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className="px-4 py-1.5 rounded-full text-xs font-semibold transition-all"
            style={{
              background: filter === f ? "#7C72E8" : "white",
              color: filter === f ? "white" : "#8B8BAD",
              border: `1.5px solid ${filter === f ? "#7C72E8" : "#E4E2FF"}`,
            }}
          >
            {f}
          </button>
        ))}
      </div>

      {/* Notes list */}
      <div className="px-5 space-y-3">
        {filtered.map((note) => (
          <div key={note.id} className="bg-white rounded-2xl border border-border p-4 flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0" style={{ background: `${note.tagColor}18` }}>
              <FileText size={18} style={{ color: note.tagColor }} />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold text-foreground">{note.title}</p>
              <p className="text-xs text-muted-foreground mt-0.5">{note.subject}</p>
              <div className="flex items-center gap-2 mt-1.5">
                <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full" style={{ background: `${note.tagColor}18`, color: note.tagColor }}>
                  {note.tag}
                </span>
                <span className="text-[10px] text-muted-foreground">{note.time} ago</span>
              </div>
            </div>
            <ChevronRight size={16} color="#C4C2E8" />
          </div>
        ))}
      </div>

      {/* Upload FAB hint */}
      <div className="mx-5 mt-5 p-4 rounded-2xl flex items-center gap-3" style={{ background: "linear-gradient(135deg, #7C72E8, #9F97F2)" }}>
        <div className="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center shrink-0">
          <Paperclip size={18} color="white" />
        </div>
        <div className="flex-1">
          <p className="text-white font-bold text-sm">Upload your notes</p>
          <p className="text-white/75 text-xs mt-0.5">Share with the community</p>
        </div>
        <ChevronRight size={18} color="white" />
      </div>
    </div>
  );
}

// ── COMMUNITY SCREEN ───────────────────────────────────────────────────────────

function CommunityScreen() {
  const [tab, setTab] = useState("Trending");
  const [posts, setPosts] = useState(POSTS);

  function toggleLike(id: number) {
    setPosts((prev) =>
      prev.map((p) =>
        p.id === id ? { ...p, liked: !p.liked, likes: p.liked ? p.likes - 1 : p.likes + 1 } : p
      )
    );
  }

  return (
    <div className="overflow-y-auto pb-24 h-full" style={{ scrollbarWidth: "none" }}>
      {/* Header */}
      <div className="px-5 pt-12 pb-4">
        <p className="text-xl font-bold text-foreground" style={{ fontFamily: "'Outfit', sans-serif" }}>Community</p>
        <p className="text-xs text-muted-foreground mt-0.5">Connect, share & learn together</p>
      </div>

      {/* Tabs */}
      <div className="px-5 mb-5 flex gap-0 bg-white rounded-2xl border border-border p-1 mx-5">
        {["Trending", "Following"].map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className="flex-1 py-2 rounded-xl text-sm font-semibold transition-all"
            style={{
              background: tab === t ? "#7C72E8" : "transparent",
              color: tab === t ? "white" : "#8B8BAD",
            }}
          >
            {t}
          </button>
        ))}
      </div>

      {/* Posts */}
      <div className="px-5 space-y-3">
        {posts.map((post) => (
          <div key={post.id} className="bg-white rounded-2xl border border-border p-4">
            {/* Author row */}
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 rounded-2xl flex items-center justify-center font-bold text-sm text-white" style={{ background: post.color }}>
                {post.init}
              </div>
              <div className="flex-1">
                <p className="text-sm font-bold text-foreground">{post.name}</p>
                <p className="text-xs text-muted-foreground">{post.time}</p>
              </div>
              <button className="text-xs font-semibold px-3 py-1 rounded-full" style={{ background: "#F3F2FF", color: "#7C72E8" }}>Follow</button>
            </div>
            {/* Content */}
            <p className="text-sm text-foreground leading-relaxed">{post.content}</p>
            {/* Actions */}
            <div className="flex items-center gap-4 mt-3 pt-3 border-t border-border">
              <button onClick={() => toggleLike(post.id)} className="flex items-center gap-1.5 transition-all">
                <Heart
                  size={17}
                  style={{ color: post.liked ? "#E91E8C" : "#9B9ABD" }}
                  fill={post.liked ? "#E91E8C" : "none"}
                />
                <span className="text-xs font-medium" style={{ color: post.liked ? "#E91E8C" : "#9B9ABD" }}>{post.likes}</span>
              </button>
              <button className="flex items-center gap-1.5">
                <MessageCircle size={17} color="#9B9ABD" />
                <span className="text-xs font-medium text-muted-foreground">{post.comments}</span>
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── AI ASSISTANT SCREEN ────────────────────────────────────────────────────────

interface Msg { id: number; role: "ai" | "user"; text: string }

function AIScreen() {
  const [messages, setMessages] = useState<Msg[]>(INIT_MSGS);
  const [input, setInput] = useState("");
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  function sendMessage() {
    const text = input.trim();
    if (!text) return;
    const userMsg: Msg = { id: Date.now(), role: "user", text };
    setMessages((prev) => [...prev, userMsg]);
    setInput("");

    setTimeout(() => {
      const aiReplies = [
        "Great question! Let me explain that concept step by step. This is a fundamental topic that forms the basis of many advanced subjects in your curriculum.",
        "That's an excellent topic to study! Here's what you need to know: The concept builds on core principles that will help you in your exams and practical applications.",
        "I can help you understand this better! Think of it this way — the main idea revolves around a few key principles that are easy to grasp once you break them down.",
      ];
      const aiMsg: Msg = { id: Date.now() + 1, role: "ai", text: aiReplies[Math.floor(Math.random() * aiReplies.length)] };
      setMessages((prev) => [...prev, aiMsg]);
    }, 900);
  }

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="px-5 pt-12 pb-4 flex items-center gap-3 bg-white border-b border-border">
        <div className="w-10 h-10 rounded-2xl flex items-center justify-center" style={{ background: "linear-gradient(135deg, #3B82F6, #6366F1)" }}>
          <Bot size={20} color="white" />
        </div>
        <div>
          <p className="text-base font-bold text-foreground" style={{ fontFamily: "'Outfit', sans-serif" }}>AI Assistant</p>
          <p className="text-xs text-muted-foreground">Powered by StudySphere AI</p>
        </div>
        <div className="ml-auto w-2 h-2 rounded-full bg-green-400" />
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-5 py-4 space-y-4 pb-4" style={{ scrollbarWidth: "none" }}>
        {messages.map((m) => (
          <div key={m.id} className={`flex gap-2.5 ${m.role === "user" ? "flex-row-reverse" : "flex-row"}`}>
            {m.role === "ai" && (
              <div className="w-8 h-8 rounded-2xl flex items-center justify-center shrink-0 mt-1" style={{ background: "linear-gradient(135deg, #3B82F6, #6366F1)" }}>
                <Bot size={15} color="white" />
              </div>
            )}
            {m.role === "user" && (
              <div className="w-8 h-8 rounded-2xl flex items-center justify-center shrink-0 mt-1 font-bold text-xs text-white" style={{ background: "#7C72E8" }}>
                O
              </div>
            )}
            <div
              className="max-w-[75%] rounded-2xl px-4 py-3 text-sm leading-relaxed"
              style={{
                background: m.role === "user" ? "#7C72E8" : "white",
                color: m.role === "user" ? "white" : "#1A1A2E",
                border: m.role === "ai" ? "1.5px solid #E4E2FF" : "none",
                borderTopRightRadius: m.role === "user" ? "6px" : "16px",
                borderTopLeftRadius: m.role === "ai" ? "6px" : "16px",
                whiteSpace: "pre-wrap",
              }}
            >
              {m.text}
            </div>
          </div>
        ))}
        <div ref={bottomRef} />
      </div>

      {/* Input bar */}
      <div className="px-4 py-3 bg-white border-t border-border mb-20">
        <div className="flex items-center gap-2 bg-[#F3F2FF] rounded-2xl px-4 py-2.5">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && sendMessage()}
            placeholder="Ask anything..."
            className="flex-1 bg-transparent text-sm text-foreground outline-none placeholder:text-muted-foreground"
          />
          <button
            onClick={sendMessage}
            className="w-8 h-8 rounded-xl flex items-center justify-center shrink-0 transition-all active:scale-95"
            style={{ background: input.trim() ? "#7C72E8" : "#C4C2E8" }}
          >
            <Send size={15} color="white" />
          </button>
        </div>
      </div>
    </div>
  );
}

// ── PROFILE SCREEN ─────────────────────────────────────────────────────────────

function ProfileScreen() {
  const stats = [
    { label: "Notes",    value: "24",   color: "#7C72E8" },
    { label: "Solved",   value: "138",  color: "#3B82F6" },
    { label: "Streak",   value: "12d",  color: "#FF8C42" },
    { label: "Rank",     value: "#142", color: "#E91E8C" },
  ];

  return (
    <div className="overflow-y-auto pb-24 h-full" style={{ scrollbarWidth: "none" }}>
      {/* Header */}
      <div className="px-5 pt-12 pb-4">
        <p className="text-xl font-bold text-foreground" style={{ fontFamily: "'Outfit', sans-serif" }}>Profile</p>
      </div>

      {/* Avatar card */}
      <div className="mx-5 bg-white rounded-3xl border border-border p-5 flex flex-col items-center">
        <div className="w-20 h-20 rounded-3xl flex items-center justify-center text-white text-2xl font-black mb-3" style={{ background: "linear-gradient(135deg, #7C72E8, #B8B2FF)" }}>
          O
        </div>
        <p className="text-lg font-bold text-foreground" style={{ fontFamily: "'Outfit', sans-serif" }}>Omkar Sharma</p>
        <p className="text-sm text-muted-foreground mt-0.5">B.Tech · Computer Science · 2nd Year</p>
        <div className="flex items-center gap-1.5 mt-2 px-3 py-1 rounded-full" style={{ background: "#F3F2FF" }}>
          <span className="text-xs font-semibold" style={{ color: "#7C72E8" }}>⭐ Top Contributor</span>
        </div>
      </div>

      {/* Stats */}
      <div className="mx-5 mt-4 grid grid-cols-4 gap-2">
        {stats.map((s) => (
          <div key={s.label} className="bg-white rounded-2xl border border-border p-3 flex flex-col items-center">
            <p className="text-base font-black" style={{ color: s.color, fontFamily: "monospace" }}>{s.value}</p>
            <p className="text-[10px] text-muted-foreground mt-0.5 font-medium">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Continue Learning */}
      <div className="mx-5 mt-4">
        <p className="text-sm font-bold text-foreground mb-3" style={{ fontFamily: "'Outfit', sans-serif" }}>My Courses</p>
        <div className="space-y-2">
          {COURSES.map((c) => (
            <div key={c.id} className="bg-white rounded-2xl border border-border p-4 flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl flex items-center justify-center font-black text-white text-sm shrink-0" style={{ background: c.bg, fontFamily: "monospace" }}>{c.icon}</div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-foreground">{c.title}</p>
                <div className="mt-1.5">
                  <div className="h-1.5 rounded-full bg-[#F3F2FF] overflow-hidden">
                    <div className="h-full rounded-full" style={{ width: `${c.progress}%`, background: c.bg }} />
                  </div>
                  <p className="text-[10px] text-muted-foreground mt-0.5">{c.progress}% complete</p>
                </div>
              </div>
              <ChevronRight size={16} color="#C4C2E8" />
            </div>
          ))}
        </div>
      </div>

      {/* Logout */}
      <div className="mx-5 mt-4">
        <button className="w-full py-3.5 rounded-2xl border border-red-200 text-red-500 text-sm font-semibold bg-white">
          Sign Out
        </button>
      </div>
    </div>
  );
}

// ── APP ────────────────────────────────────────────────────────────────────────

export default function App() {
  const [tab, setTab] = useState("home");

  return (
    <div className="bg-[#E8E7FF] min-h-screen flex items-start justify-center" style={{ fontFamily: "'Inter', sans-serif" }}>
      <div className="w-full max-w-[390px] min-h-screen bg-[#F0EFFF] relative flex flex-col">
        <div className="flex-1 overflow-hidden relative">
          {tab === "home"      && <HomeScreen goNotes={() => setTab("notes")} goCommunity={() => setTab("community")} goAI={() => setTab("ai")} />}
          {tab === "notes"     && <NotesScreen />}
          {tab === "community" && <CommunityScreen />}
          {tab === "ai"        && <AIScreen />}
          {tab === "profile"   && <ProfileScreen />}
        </div>
        <BottomNav active={tab} onChange={setTab} />
      </div>
    </div>
  );
}
