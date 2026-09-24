// ProfessorOS Standalone React Component: QuizBuilderPage
const { useState, useEffect, useMemo } = React;

const API_BASE = "/api/v1" || "/api/v1";

const BLOOM_COLORS = {
  C1: { bg: "bg-slate-100", text: "text-slate-700", border: "border-slate-300", bar: "bg-slate-400" },
  C2: { bg: "bg-blue-100", text: "text-blue-700", border: "border-blue-300", bar: "bg-blue-500" },
  C3: { bg: "bg-emerald-100", text: "text-emerald-700", border: "border-emerald-300", bar: "bg-emerald-500" },
  C4: { bg: "bg-amber-100", text: "text-amber-700", border: "border-amber-300", bar: "bg-amber-500" },
  C5: { bg: "bg-orange-100", text: "text-orange-700", border: "border-orange-300", bar: "bg-orange-500" },
  C6: { bg: "bg-rose-100", text: "text-rose-700", border: "border-rose-300", bar: "bg-rose-500" },
};

window.QuizBuilderPage = function QuizBuilderPage({ courseId, initialQuizId = "" }) {
  const [quizId, setQuizId] = useState(initialQuizId);
  const [availableQuestions, setAvailableQuestions] = useState([]);
  const [selectedQuestions, setSelectedQuestions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [isPublished, setIsPublished] = useState(false);

  // Filters for left panel
  const [bloomFilter, setBloomFilter] = useState("");
  const [searchQuery, setSearchQuery] = useState("");
  const [cloFilter, setCloFilter] = useState("");

  // Gate Violation / Success Modal
  const [gateModalData, setGateModalData] = useState(null);
  const [toastMessage, setToastMessage] = useState(null);

  useEffect(() => {
    fetchApprovedQuestions();
  }, [courseId]);

  const showToast = (msg, type = "success") => {
    setToastMessage({ msg, type });
    setTimeout(() => setToastMessage(null), 4000);
  };

  const fetchApprovedQuestions = async () => {
    setLoading(true);
    try {
      const token = localStorage.getItem("token");
      const res = await fetch(`${API_BASE}/courses/${courseId}/question-bank?status=APPROVED`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setAvailableQuestions(data);
        // Pre-select first 3 as initial draft if empty
        if (selectedQuestions.length === 0 && data.length > 0) {
          setSelectedQuestions(data.slice(0, Math.min(3, data.length)).map(q => ({ ...q, points: 1.0 })));
        }
      }
    } catch (err) {
      console.error("Failed to load approved questions:", err);
    } finally {
      setLoading(false);
    }
  };

  // Add question to right panel
  const handleAddQuestion = (q) => {
    if (selectedQuestions.some((sq) => sq.question_id === q.question_id)) return;
    setSelectedQuestions((prev) => [...prev, { ...q, points: 1.0 }]);
  };

  // Remove question from right panel
  const handleRemoveQuestion = (qId) => {
    setSelectedQuestions((prev) => prev.filter((q) => q.question_id !== qId));
  };

  // Change individual question points
  const handlePointsChange = (qId, points) => {
    const p = Math.max(0.5, parseFloat(points) || 1.0);
    setSelectedQuestions((prev) =>
      prev.map((q) => (q.question_id === qId ? { ...q, points: p } : q))
    );
  };

  // Move question up/down
  const handleMove = (index, direction) => {
    const newIdx = index + direction;
    if (newIdx < 0 || newIdx >= selectedQuestions.length) return;
    const updated = [...selectedQuestions];
    const temp = updated[index];
    updated[index] = updated[newIdx];
    updated[newIdx] = temp;
    setSelectedQuestions(updated);
  };

  // Live Bloom Distribution Calculation
  const bloomStats = useMemo(() => {
    const counts = { C1: 0, C2: 0, C3: 0, C4: 0, C5: 0, C6: 0 };
    const total = selectedQuestions.length;
    selectedQuestions.forEach((q) => {
      const lvl = q.bloom_level ? q.bloom_level.toUpperCase() : "C1";
      if (counts[lvl] !== undefined) counts[lvl]++;
    });

    const percentages = {};
    Object.keys(counts).forEach((lvl) => {
      percentages[lvl] = total > 0 ? ((counts[lvl] / total) * 100).toFixed(1) : 0;
    });

    const c1Pct = parseFloat(percentages.C1);
    const c3PlusPct =
      parseFloat(percentages.C3) +
      parseFloat(percentages.C4) +
      parseFloat(percentages.C5) +
      parseFloat(percentages.C6);

    const c1Pass = total > 0 ? c1Pct <= 30.0 : true;
    const c3PlusPass = total > 0 ? c3PlusPct >= 30.0 : false;
    const totalPoints = selectedQuestions.reduce((acc, q) => acc + (q.points || 1.0), 0);

    return { counts, percentages, total, c1Pct, c3PlusPct, c1Pass, c3PlusPass, totalPoints };
  }, [selectedQuestions]);

  // Save selected questions to Quiz
  const handleSaveQuestions = async () => {
    if (!quizId) {
      alert("Please enter a valid Quiz UUID.");
      return;
    }
    if (selectedQuestions.length === 0) {
      alert("Please add at least one question before saving.");
      return;
    }

    setSaving(true);
    try {
      const token = localStorage.getItem("token");
      const res = await fetch(`${API_BASE}/quizzes/${quizId}/questions`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          question_ids: selectedQuestions.map((q) => q.question_id),
          points_per_question: 1.0,
        }),
      });

      const data = await res.json();
      if (res.ok) {
        showToast(`Saved ${selectedQuestions.length} questions to assessment!`);
      } else {
        alert(data.detail || "Failed to save questions to quiz.");
      }
    } catch (err) {
      console.error("Save error:", err);
      alert("Network error while linking questions.");
    } finally {
      setSaving(false);
    }
  };

  // Publish Quiz with Mandatory Gate Check
  const handlePublishQuiz = async () => {
    if (!quizId) return;
    setPublishing(true);
    try {
      // First ensure questions are saved
      const token = localStorage.getItem("token");
      await fetch(`${API_BASE}/quizzes/${quizId}/questions`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          question_ids: selectedQuestions.map((q) => q.question_id),
          points_per_question: 1.0,
        }),
      });

      // Now call publish
      const res = await fetch(`${API_BASE}/quizzes/${quizId}/publish`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      });

      const data = await res.json();

      if (res.ok) {
        setIsPublished(true);
        showToast("Quiz passed HEC Quality Gate & successfully published!", "success");
      } else {
        // Gate failed - display HEC modal
        setGateModalData({
          title: "HEC / Washington Accord Bloom Gate Rejection",
          message: data.detail?.message || "Assessment failed cognitive distribution guidelines.",
          violations: data.detail?.violations || ["Cognitive balance does not satisfy OBE minimum criteria."],
          recommendations: data.detail?.recommendations || ["Increase Higher-Order Thinking questions (C3-C6)."],
          distribution: data.detail?.bloom_distribution || bloomStats.percentages,
        });
      }
    } catch (err) {
      console.error("Publish error:", err);
      alert("Encountered an unexpected error during quiz publication.");
    } finally {
      setPublishing(false);
    }
  };

  // Filter available questions
  const filteredAvailable = availableQuestions.filter((q) => {
    if (bloomFilter && q.bloom_level !== bloomFilter) return false;
    if (cloFilter && (!q.clo_id || !q.clo_id.toLowerCase().includes(cloFilter.toLowerCase()))) return false;
    if (searchQuery) {
      const qLower = searchQuery.toLowerCase();
      const matchText = q.question_text.toLowerCase().includes(qLower);
      const matchClo = q.clo_id && q.clo_id.toLowerCase().includes(qLower);
      if (!matchText && !matchClo) return false;
    }
    return true;
  });

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 pb-36 font-sans">
      {/* Toast Notification */}
      {toastMessage && (
        <div
          className={`fixed top-5 right-5 z-50 px-5 py-3 rounded-lg shadow-xl font-medium border flex items-center gap-3 transition-all ${
            toastMessage.type === "success"
              ? "bg-emerald-600 text-white border-emerald-700"
              : "bg-rose-600 text-white border-rose-700"
          }`}
        >
          <svg className="w-5 h-5 fill-current" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
          </svg>
          {toastMessage.msg}
        </div>
      )}

      {/* Top Header */}
      <header className="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-sm">
        <div className="max-w-7xl mx-auto px-6 py-4 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
          <div>
            <div className="flex items-center gap-3">
              <span className="bg-indigo-600 text-white p-2 rounded-lg shadow-sm">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                </svg>
              </span>
              <div>
                <h1 className="text-xl font-bold text-slate-800 flex items-center gap-2">
                  Interactive OBE Quiz Builder
                  {isPublished && (
                    <span className="text-xs bg-emerald-100 text-emerald-800 border border-emerald-300 font-semibold px-2 py-0.5 rounded-full">
                      PUBLISHED
                    </span>
                  )}
                </h1>
                <p className="text-xs text-slate-500">
                  Course ID #{courseId} &bull; Washington Accord / HEC Accreditation Calibrated
                </p>
              </div>
            </div>
          </div>

          {/* Quiz UUID Bar & Primary Actions */}
          <div className="flex items-center gap-3">
            <div className="flex items-center bg-slate-100 border border-slate-300 rounded-lg px-3 py-1.5 text-xs text-slate-600 font-mono">
              <span className="text-slate-400 mr-2">Quiz UUID:</span>
              <input
                type="text"
                value={quizId}
                onChange={(e) => setQuizId(e.target.value)}
                className="bg-transparent border-none focus:outline-none w-48 text-slate-800 font-mono text-xs"
                placeholder="Paste quiz UUID..."
              />
            </div>

            <button
              onClick={handleSaveQuestions}
              disabled={saving}
              className="px-4 py-2 bg-white border border-slate-300 hover:bg-slate-50 text-slate-700 font-medium text-xs rounded-lg shadow-sm transition-all flex items-center gap-2"
            >
              {saving ? "Saving..." : "Save Draft"}
            </button>

            <button
              onClick={handlePublishQuiz}
              disabled={publishing || selectedQuestions.length === 0}
              className={`px-5 py-2 font-medium text-xs rounded-lg shadow-sm transition-all flex items-center gap-2 text-white ${
                bloomStats.c1Pass && bloomStats.c3PlusPass && selectedQuestions.length > 0
                  ? "bg-indigo-600 hover:bg-indigo-700 shadow-indigo-100"
                  : "bg-slate-700 hover:bg-slate-800"
              }`}
            >
              {publishing ? (
                <>
                  <svg className="animate-spin h-3.5 w-3.5 text-white" viewBox="0 0 24 24" fill="none">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
                  </svg>
                  Validating Gate...
                </>
              ) : (
                <>
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" />
                  </svg>
                  Publish Assessment
                </>
              )}
            </button>
          </div>
        </div>
      </header>

      {/* Main Split Panel Layout */}
      <main className="max-w-7xl mx-auto px-6 py-6 grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Question Repository */}
        <section className="lg:col-span-6 bg-white border border-slate-200 rounded-xl shadow-sm flex flex-col h-[750px] overflow-hidden">
          {/* Header & Filter Controls */}
          <div className="p-4 border-b border-slate-100 bg-slate-50/50">
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-sm font-bold text-slate-800 flex items-center gap-2">
                <span>Approved Question Bank</span>
                <span className="bg-slate-200 text-slate-700 text-xs px-2 py-0.5 rounded-full font-mono">
                  {filteredAvailable.length} available
                </span>
              </h2>
              <button
                onClick={fetchApprovedQuestions}
                className="text-xs text-indigo-600 hover:text-indigo-800 font-medium"
              >
                Refresh
              </button>
            </div>

            {/* Search Input */}
            <div className="relative mb-2">
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search concepts or CLO keywords..."
                className="w-full pl-9 pr-3 py-1.5 text-xs bg-white border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
              />
              <svg className="w-4 h-4 absolute left-2.5 top-2 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>

            {/* Bloom & CLO Filters */}
            <div className="flex items-center gap-2">
              <select
                value={bloomFilter}
                onChange={(e) => setBloomFilter(e.target.value)}
                className="text-xs bg-white border border-slate-200 rounded-lg px-2.5 py-1 text-slate-700 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              >
                <option value="">All Bloom Levels</option>
                <option value="C1">C1 - Remember</option>
                <option value="C2">C2 - Understand</option>
                <option value="C3">C3 - Apply</option>
                <option value="C4">C4 - Analyze</option>
                <option value="C5">C5 - Evaluate</option>
                <option value="C6">C6 - Create</option>
              </select>

              <input
                type="text"
                value={cloFilter}
                onChange={(e) => setCloFilter(e.target.value)}
                placeholder="Filter CLO (e.g. CLO-1)"
                className="text-xs bg-white border border-slate-200 rounded-lg px-2.5 py-1 text-slate-700 w-36 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              />
            </div>
          </div>

          {/* List of Available Questions */}
          <div className="flex-1 overflow-y-auto p-4 space-y-3">
            {loading ? (
              <div className="flex flex-col items-center justify-center h-48 text-slate-400 gap-2">
                <svg className="animate-spin h-6 w-6 text-indigo-500" viewBox="0 0 24 24" fill="none">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
                </svg>
                <span className="text-xs">Loading approved questions...</span>
              </div>
            ) : filteredAvailable.length === 0 ? (
              <div className="text-center py-12 text-slate-400 text-xs">
                No approved questions match criteria.
              </div>
            ) : (
              filteredAvailable.map((q) => {
                const isSelected = selectedQuestions.some((sq) => sq.question_id === q.question_id);
                const bloom = BLOOM_COLORS[q.bloom_level] || BLOOM_COLORS.C1;

                return (
                  <div
                    key={q.question_id}
                    className={`border rounded-xl p-3.5 transition-all text-xs ${
                      isSelected
                        ? "bg-slate-50/80 border-slate-200 opacity-60"
                        : "bg-white border-slate-200 hover:border-indigo-300 hover:shadow-sm"
                    }`}
                  >
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center gap-1.5">
                        <span className={`px-2 py-0.5 rounded text-[11px] font-bold border ${bloom.bg} ${bloom.text} ${bloom.border}`}>
                          {q.bloom_level}
                        </span>
                        {q.clo_id && (
                          <span className="bg-indigo-50 text-indigo-700 border border-indigo-200 px-2 py-0.5 rounded text-[11px] font-mono">
                            {q.clo_id}
                          </span>
                        )}
                        <span className="text-slate-400 text-[10px]">
                          Diff: {(q.difficulty * 10).toFixed(0)}/10
                        </span>
                      </div>

                      <button
                        onClick={() => handleAddQuestion(q)}
                        disabled={isSelected}
                        className={`px-2.5 py-1 rounded text-xs font-medium transition-all ${
                          isSelected
                            ? "bg-slate-100 text-slate-400 cursor-not-allowed"
                            : "bg-indigo-50 text-indigo-700 hover:bg-indigo-100 border border-indigo-200"
                        }`}
                      >
                        {isSelected ? "In Assessment ✓" : "+ Add"}
                      </button>
                    </div>

                    <p className="text-slate-800 font-medium mb-2 leading-relaxed">
                      {q.question_text}
                    </p>

                    {/* Options Preview */}
                    {Array.isArray(q.options) && (
                      <div className="grid grid-cols-2 gap-1 text-[11px] text-slate-500 bg-slate-50 p-2 rounded border border-slate-100">
                        {q.options.slice(0, 4).map((opt, i) => (
                          <div key={i} className="truncate">
                            &bull; {typeof opt === "string" ? opt : opt.text}
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                );
              })
            )}
          </div>
        </section>

        {/* Right Column: Active Quiz Canvas */}
        <section className="lg:col-span-6 bg-white border border-slate-200 rounded-xl shadow-sm flex flex-col h-[750px] overflow-hidden">
          {/* Header with Counter and Total Points */}
          <div className="p-4 border-b border-slate-100 bg-slate-50/50 flex items-center justify-between">
            <div>
              <h2 className="text-sm font-bold text-slate-800 flex items-center gap-2">
                <span>Assessment Structure</span>
                <span className="bg-indigo-100 text-indigo-800 text-xs px-2 py-0.5 rounded-full font-mono font-semibold">
                  {selectedQuestions.length} Questions
                </span>
              </h2>
              <p className="text-[11px] text-slate-500 mt-0.5">
                Total Score: <span className="font-semibold text-slate-700">{bloomStats.totalPoints} Marks</span>
              </p>
            </div>

            {selectedQuestions.length > 0 && (
              <button
                onClick={() => setSelectedQuestions([])}
                className="text-xs text-rose-600 hover:text-rose-800 font-medium"
              >
                Clear All
              </button>
            )}
          </div>

          {/* Selected Questions Canvas */}
          <div className="flex-1 overflow-y-auto p-4 space-y-3">
            {selectedQuestions.length === 0 ? (
              <div className="h-full flex flex-col items-center justify-center text-center p-8 text-slate-400">
                <div className="w-12 h-12 rounded-full bg-slate-100 flex items-center justify-center mb-3">
                  <svg className="w-6 h-6 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                  </svg>
                </div>
                <h3 className="text-sm font-medium text-slate-700 mb-1">Canvas is empty</h3>
                <p className="text-xs max-w-xs">
                  Select questions from the left approved bank to construct this assessment.
                </p>
              </div>
            ) : (
              selectedQuestions.map((q, index) => {
                const bloom = BLOOM_COLORS[q.bloom_level] || BLOOM_COLORS.C1;
                return (
                  <div
                    key={q.question_id}
                    className="border border-slate-200 rounded-xl p-3.5 bg-white shadow-sm hover:border-slate-300 transition-all text-xs"
                  >
                    <div className="flex items-start justify-between gap-2 mb-2">
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-slate-400 font-bold w-5">
                          #{index + 1}
                        </span>
                        <span className={`px-2 py-0.5 rounded text-[11px] font-bold border ${bloom.bg} ${bloom.text} ${bloom.border}`}>
                          {q.bloom_level}
                        </span>
                        {q.clo_id && (
                          <span className="bg-indigo-50 text-indigo-700 border border-indigo-200 px-2 py-0.5 rounded text-[11px] font-mono">
                            {q.clo_id}
                          </span>
                        )}
                      </div>

                      {/* Controls: Move Up, Move Down, Points, Delete */}
                      <div className="flex items-center gap-1.5">
                        <div className="flex items-center bg-slate-100 rounded px-1.5 py-0.5 text-[11px]">
                          <span className="text-slate-500 mr-1">Pts:</span>
                          <input
                            type="number"
                            step="0.5"
                            min="0.5"
                            value={q.points || 1.0}
                            onChange={(e) => handlePointsChange(q.question_id, e.target.value)}
                            className="w-10 bg-transparent text-slate-800 font-mono font-medium focus:outline-none text-center"
                          />
                        </div>

                        {/* Move Up */}
                        <button
                          onClick={() => handleMove(index, -1)}
                          disabled={index === 0}
                          className="p-1 text-slate-400 hover:text-slate-700 disabled:opacity-30"
                          title="Move Up"
                        >
                          &uarr;
                        </button>
                        {/* Move Down */}
                        <button
                          onClick={() => handleMove(index, 1)}
                          disabled={index === selectedQuestions.length - 1}
                          className="p-1 text-slate-400 hover:text-slate-700 disabled:opacity-30"
                          title="Move Down"
                        >
                          &darr;
                        </button>

                        {/* Remove */}
                        <button
                          onClick={() => handleRemoveQuestion(q.question_id)}
                          className="p-1 text-rose-500 hover:text-rose-700 ml-1"
                          title="Remove"
                        >
                          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                          </svg>
                        </button>
                      </div>
                    </div>

                    <p className="text-slate-800 font-medium leading-relaxed pl-7">
                      {q.question_text}
                    </p>
                  </div>
                );
              })
            )}
          </div>
        </section>
      </main>

      {/* Sticky Bottom OBE Quality Gate & Bloom Distribution Bar */}
      <footer className="fixed bottom-0 left-0 right-0 bg-white border-t border-slate-200 shadow-2xl z-40 p-4">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row md:items-center justify-between gap-4">
          {/* Left: HEC Compliance Flags */}
          <div className="flex items-center gap-6">
            <div>
              <div className="text-[11px] font-bold uppercase tracking-wider text-slate-400">
                Cognitive Guardrails
              </div>
              <div className="flex items-center gap-4 mt-1">
                {/* C1 Check */}
                <div className="flex items-center gap-1.5 text-xs">
                  <span
                    className={`w-2.5 h-2.5 rounded-full ${
                      bloomStats.c1Pass ? "bg-emerald-500" : "bg-rose-500 animate-pulse"
                    }`}
                  />
                  <span className="font-semibold text-slate-700">C1 Recall:</span>
                  <span
                    className={`font-mono ${
                      bloomStats.c1Pass ? "text-emerald-700 font-bold" : "text-rose-700 font-bold"
                    }`}
                  >
                    {bloomStats.c1Pct}%
                  </span>
                  <span className="text-[10px] text-slate-400">(Max 30%)</span>
                </div>

                {/* C3+ Check */}
                <div className="flex items-center gap-1.5 text-xs">
                  <span
                    className={`w-2.5 h-2.5 rounded-full ${
                      bloomStats.c3PlusPass ? "bg-emerald-500" : "bg-amber-500 animate-pulse"
                    }`}
                  />
                  <span className="font-semibold text-slate-700">C3+ Application:</span>
                  <span
                    className={`font-mono ${
                      bloomStats.c3PlusPass ? "text-emerald-700 font-bold" : "text-amber-700 font-bold"
                    }`}
                  >
                    {bloomStats.c3PlusPct}%
                  </span>
                  <span className="text-[10px] text-slate-400">(Min 30%)</span>
                </div>
              </div>
            </div>

            {/* Overall Gate Status Badge */}
            <div className="border-l border-slate-200 pl-4 hidden sm:block">
              <span
                className={`px-3 py-1 rounded-full text-xs font-bold border ${
                  bloomStats.c1Pass && bloomStats.c3PlusPass && bloomStats.total > 0
                    ? "bg-emerald-50 text-emerald-800 border-emerald-300"
                    : "bg-amber-50 text-amber-800 border-amber-300"
                }`}
              >
                {bloomStats.c1Pass && bloomStats.c3PlusPass && bloomStats.total > 0
                  ? "HEC Gate Passed ✓"
                  : "Gate Violations Pending ⚠"}
              </span>
            </div>
          </div>

          {/* Right: Visual Distribution Progress Bar */}
          <div className="flex-1 max-w-md">
            <div className="flex justify-between text-[11px] text-slate-500 mb-1 font-mono">
              <span>C1: {bloomStats.percentages.C1}%</span>
              <span>C2: {bloomStats.percentages.C2}%</span>
              <span>C3: {bloomStats.percentages.C3}%</span>
              <span>C4: {bloomStats.percentages.C4}%</span>
              <span>C5: {bloomStats.percentages.C5}%</span>
              <span>C6: {bloomStats.percentages.C6}%</span>
            </div>

            <div className="h-3 w-full bg-slate-100 rounded-full overflow-hidden flex shadow-inner">
              {Object.keys(BLOOM_COLORS).map((lvl) => {
                const pct = bloomStats.percentages[lvl] || 0;
                if (pct <= 0) return null;
                return (
                  <div
                    key={lvl}
                    style={{ width: `${pct}%` }}
                    className={`${BLOOM_COLORS[lvl].bar} transition-all duration-300`}
                    title={`${lvl}: ${pct}%`}
                  />
                );
              })}
            </div>
          </div>
        </div>
      </footer>

      {/* Gate Violation Modal */}
      {gateModalData && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl border border-rose-200 animate-in fade-in zoom-in duration-150">
            <div className="w-12 h-12 rounded-full bg-rose-100 text-rose-600 flex items-center justify-center mb-4">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            </div>

            <h3 className="text-lg font-bold text-slate-800 mb-1">{gateModalData.title}</h3>
            <p className="text-xs text-slate-500 mb-4">{gateModalData.message}</p>

            {/* Violations List */}
            <div className="mb-4">
              <span className="text-xs font-bold text-rose-800 uppercase tracking-wider block mb-1">
                Detected Deficiencies:
              </span>
              <ul className="space-y-1.5 bg-rose-50 border border-rose-100 rounded-xl p-3 text-xs text-rose-900">
                {gateModalData.violations.map((v, i) => (
                  <li key={i} className="flex items-start gap-2">
                    <span className="text-rose-600 font-bold">&bull;</span>
                    <span>{v}</span>
                  </li>
                ))}
              </ul>
            </div>

            {/* Recommendations */}
            {gateModalData.recommendations && (
              <div className="mb-5">
                <span className="text-xs font-bold text-slate-700 uppercase tracking-wider block mb-1">
                  Required Corrective Action:
                </span>
                <ul className="space-y-1 bg-slate-50 border border-slate-200 rounded-xl p-3 text-xs text-slate-600">
                  {gateModalData.recommendations.map((r, i) => (
                    <li key={i} className="flex items-start gap-2">
                      <span className="text-indigo-500">&rarr;</span>
                      <span>{r}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}

            <div className="flex justify-end">
              <button
                onClick={() => setGateModalData(null)}
                className="px-5 py-2 bg-slate-800 hover:bg-slate-900 text-white text-xs font-semibold rounded-lg shadow-sm"
              >
                Return to Editor & Rectify
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
