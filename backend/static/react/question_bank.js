// ProfessorOS Standalone React Component: QuestionBankPage
const { useState, useEffect, useMemo } = React;

const API_BASE = "/api/v1" || "/api/v1";

const BLOOM_COLORS = {
  C1: "bg-slate-100 text-slate-700 border-slate-300",
  C2: "bg-blue-100 text-blue-700 border-blue-300",
  C3: "bg-emerald-100 text-emerald-700 border-emerald-300",
  C4: "bg-amber-100 text-amber-700 border-amber-300",
  C5: "bg-orange-100 text-orange-700 border-orange-300",
  C6: "bg-red-100 text-red-700 border-red-300",
};

const STATUS_BADGES = {
  APPROVED: "bg-emerald-50 text-emerald-700 border-emerald-200",
  DRAFT: "bg-amber-50 text-amber-700 border-amber-200",
  ARCHIVED: "bg-slate-50 text-slate-500 border-slate-200",
};

window.QuestionBankPage = function QuestionBankPage({ courseId = 4 }) {
  const [questions, setQuestions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState("");
  const [bloomFilter, setBloomFilter] = useState("");
  const [searchQuery, setSearchQuery] = useState("");
  const [expandedRationale, setExpandedRationale] = useState({});
  const [editingQuestion, setEditingQuestion] = useState(null);
  const [actionLoading, setActionLoading] = useState({});

  useEffect(() => {
    fetchQuestions();
  }, [courseId, statusFilter, bloomFilter]);

  const fetchQuestions = async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams();
      if (statusFilter) params.append("status", statusFilter);
      if (bloomFilter) params.append("bloom_level", bloomFilter);

      const token = localStorage.getItem("token");
      const res = await fetch(`${API_BASE}/courses/${courseId}/question-bank?${params.toString()}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setQuestions(data);
      }
    } catch (err) {
      console.error("Failed loading questions:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async (qId) => {
    setActionLoading((prev) => ({ ...prev, [qId]: true }));
    try {
      const token = localStorage.getItem("token");
      const res = await fetch(`${API_BASE}/question-bank/${qId}/approve`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        setQuestions((prev) =>
          prev.map((q) => (q.question_id === qId ? { ...q, status: "APPROVED" } : q))
        );
      }
    } finally {
      setActionLoading((prev) => ({ ...prev, [qId]: false }));
    }
  };

  const handleReject = async (qId) => {
    setActionLoading((prev) => ({ ...prev, [qId]: true }));
    try {
      const token = localStorage.getItem("token");
      const res = await fetch(`${API_BASE}/question-bank/${qId}/reject`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        setQuestions((prev) =>
          prev.map((q) => (q.question_id === qId ? { ...q, status: "ARCHIVED" } : q))
        );
      }
    } finally {
      setActionLoading((prev) => ({ ...prev, [qId]: false }));
    }
  };

  const handleSaveEdit = async () => {
    if (!editingQuestion) return;
    const token = localStorage.getItem("token");
    try {
      const res = await fetch(`${API_BASE}/question-bank/${editingQuestion.question_id}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          question_text: editingQuestion.question_text,
          bloom_level: editingQuestion.bloom_level,
          difficulty: parseFloat(editingQuestion.difficulty),
        }),
      });
      if (res.ok) {
        const updated = await res.json();
        setQuestions((prev) =>
          prev.map((q) => (q.question_id === updated.question_id ? updated : q))
        );
        setEditingQuestion(null);
      }
    } catch (err) {
      console.error("Edit failed:", err);
    }
  };

  const filtered = questions.filter((q) =>
    q.question_text.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="max-w-7xl mx-auto px-4 py-8 bg-slate-50 min-h-screen">
      {/* Header */}
      <div className="mb-6 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Question Repository & Calibration</h1>
          <p className="text-sm text-slate-500 mt-1">
            Audit Bloom's taxonomy balance, verify distractor rationales, and approve questions for assessments.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-xs font-semibold px-2.5 py-1 bg-white border border-slate-200 rounded-lg text-slate-700 shadow-sm">
            Total Items: {filtered.length}
          </span>
        </div>
      </div>

      {/* Filter Bar */}
      <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm mb-6 flex flex-wrap items-center gap-3">
        <div className="flex-1 min-w-[240px]">
          <input
            type="text"
            placeholder="Search questions by text or concept..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full px-3.5 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <select
          value={bloomFilter}
          onChange={(e) => setBloomFilter(e.target.value)}
          className="px-3 py-2 text-sm border border-slate-300 rounded-lg bg-white focus:outline-none focus:ring-2 focus:ring-blue-500 text-slate-700"
        >
          <option value="">All Bloom Levels</option>
          <option value="C1">C1: Remember</option>
          <option value="C2">C2: Understand</option>
          <option value="C3">C3: Apply</option>
          <option value="C4">C4: Analyze</option>
          <option value="C5">C5: Evaluate</option>
          <option value="C6">C6: Create</option>
        </select>

        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-3 py-2 text-sm border border-slate-300 rounded-lg bg-white focus:outline-none focus:ring-2 focus:ring-blue-500 text-slate-700"
        >
          <option value="">All Statuses</option>
          <option value="DRAFT">DRAFT (Needs Review)</option>
          <option value="APPROVED">APPROVED (Ready for Quiz)</option>
          <option value="ARCHIVED">ARCHIVED</option>
        </select>
      </div>

      {/* Questions List */}
      {loading ? (
        <div className="text-center py-20 text-slate-500 text-sm animate-pulse">Loading question items...</div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-slate-200 text-slate-500">
          No questions match your current filters.
        </div>
      ) : (
        <div className="space-y-4">
          {filtered.map((q) => {
            const bloomStyle = BLOOM_COLORS[q.bloom_level] || "bg-slate-100 text-slate-700 border-slate-200";
            const statusStyle = STATUS_BADGES[q.status] || "bg-slate-50 text-slate-600 border-slate-200";
            const diffPct = Math.round((q.difficulty || 0.5) * 100);
            const isExpanded = !!expandedRationale[q.question_id];

            let rationaleText = null;
            if (q.metadata_json && typeof q.metadata_json === "object") {
              rationaleText = q.metadata_json.distractor_rationales || q.metadata_json.explanation;
            }

            return (
              <div
                key={q.question_id}
                className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm hover:border-slate-300 transition"
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="flex-1">
                    {/* Badges Bar */}
                    <div className="flex flex-wrap items-center gap-2 mb-2">
                      <span className={`text-xs font-semibold px-2.5 py-0.5 rounded-md border ${bloomStyle}`}>
                        {q.bloom_level}
                      </span>
                      <span className="text-xs font-medium px-2 py-0.5 rounded-md bg-slate-100 text-slate-600 border border-slate-200">
                        {q.question_type}
                      </span>
                      <span className={`text-xs font-semibold px-2 py-0.5 rounded-md border ${statusStyle}`}>
                        {q.status}
                      </span>
                      {q.clo_id && (
                        <span className="text-xs text-indigo-700 bg-indigo-50 border border-indigo-200 px-2 py-0.5 rounded-md">
                          Linked CLO
                        </span>
                      )}
                    </div>

                    {/* Question Prompt */}
                    <p className="text-base font-semibold text-slate-900 leading-relaxed">{q.question_text}</p>

                    {/* MCQ Options preview */}
                    {q.options && Array.isArray(q.options) && (
                      <div className="mt-3 grid grid-cols-1 md:grid-cols-2 gap-2">
                        {q.options.map((opt, i) => (
                          <div
                            key={i}
                            className={`text-xs px-3 py-1.5 rounded-lg border ${
                              q.correct_answer && opt.toLowerCase().includes(q.correct_answer.toLowerCase())
                                ? "bg-emerald-50 border-emerald-200 text-emerald-800 font-medium"
                                : "bg-slate-50 border-slate-200 text-slate-700"
                            }`}
                          >
                            {opt}
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Actions Column */}
                  <div className="flex flex-col items-end gap-2 shrink-0">
                    <div className="flex items-center gap-1.5">
                      {q.status !== "APPROVED" && (
                        <button
                          disabled={actionLoading[q.question_id]}
                          onClick={() => handleApprove(q.question_id)}
                          className="px-3 py-1 text-xs font-semibold rounded-lg bg-emerald-600 text-white hover:bg-emerald-700 transition"
                        >
                          Approve
                        </button>
                      )}
                      {q.status !== "ARCHIVED" && (
                        <button
                          disabled={actionLoading[q.question_id]}
                          onClick={() => handleReject(q.question_id)}
                          className="px-3 py-1 text-xs font-semibold rounded-lg bg-slate-200 text-slate-700 hover:bg-slate-300 transition"
                        >
                          Reject
                        </button>
                      )}
                      <button
                        onClick={() => setEditingQuestion(q)}
                        className="px-2.5 py-1 text-xs font-medium rounded-lg border border-slate-300 hover:bg-slate-50 text-slate-700"
                      >
                        Edit
                      </button>
                    </div>

                    {/* Difficulty Indicator */}
                    <div className="w-32 mt-2">
                      <div className="flex justify-between text-[11px] text-slate-500 mb-1">
                        <span>Difficulty</span>
                        <span className="font-semibold">{diffPct}%</span>
                      </div>
                      <div className="w-full bg-slate-100 rounded-full h-1.5 overflow-hidden">
                        <div
                          className="bg-blue-600 h-1.5 rounded-full"
                          style={{ width: `${diffPct}%` }}
                        />
                      </div>
                    </div>
                  </div>
                </div>

                {/* Accordion: Distractor Rationales */}
                {rationaleText && (
                  <div className="mt-4 pt-3 border-t border-slate-100">
                    <button
                      onClick={() =>
                        setExpandedRationale((prev) => ({
                          ...prev,
                          [q.question_id]: !prev[q.question_id],
                        }))
                      }
                      className="text-xs font-semibold text-blue-600 hover:text-blue-800 flex items-center gap-1"
                    >
                      <span>{isExpanded ? "Hide" : "Show"} Pedagogical Distractor Rationales</span>
                      <span>{isExpanded ? "▲" : "▼"}</span>
                    </button>

                    {isExpanded && (
                      <div className="mt-2 text-xs text-slate-600 bg-blue-50/50 border border-blue-100 p-3 rounded-lg leading-relaxed">
                        {typeof rationaleText === "string" ? rationaleText : JSON.stringify(rationaleText, null, 2)}
                      </div>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* Edit Modal */}
      {editingQuestion && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl max-w-lg w-full p-6 shadow-xl border border-slate-200">
            <h3 className="text-lg font-bold text-slate-900 mb-4">Edit Question Calibration</h3>

            <div className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">Question Prompt</label>
                <textarea
                  rows={3}
                  value={editingQuestion.question_text}
                  onChange={(e) =>
                    setEditingQuestion({ ...editingQuestion, question_text: e.target.value })
                  }
                  className="w-full p-2.5 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-slate-700 block mb-1">Bloom's Level</label>
                  <select
                    value={editingQuestion.bloom_level}
                    onChange={(e) =>
                      setEditingQuestion({ ...editingQuestion, bloom_level: e.target.value })
                    }
                    className="w-full p-2 text-sm border border-slate-300 rounded-lg"
                  >
                    <option value="C1">C1: Remember</option>
                    <option value="C2">C2: Understand</option>
                    <option value="C3">C3: Apply</option>
                    <option value="C4">C4: Analyze</option>
                    <option value="C5">C5: Evaluate</option>
                    <option value="C6">C6: Create</option>
                  </select>
                </div>

                <div>
                  <label className="text-xs font-semibold text-slate-700 block mb-1">Difficulty (0.1 - 1.0)</label>
                  <input
                    type="number"
                    step="0.05"
                    min="0.1"
                    max="1.0"
                    value={editingQuestion.difficulty}
                    onChange={(e) =>
                      setEditingQuestion({ ...editingQuestion, difficulty: e.target.value })
                    }
                    className="w-full p-2 text-sm border border-slate-300 rounded-lg"
                  />
                </div>
              </div>
            </div>

            <div className="mt-6 flex justify-end gap-2">
              <button
                onClick={() => setEditingQuestion(null)}
                className="px-4 py-2 text-sm rounded-lg border border-slate-300 text-slate-700 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveEdit}
                className="px-4 py-2 text-sm font-semibold rounded-lg bg-blue-600 text-white hover:bg-blue-700"
              >
                Save Changes
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
