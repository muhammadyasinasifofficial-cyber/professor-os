// ProfessorOS Standalone React Component: OBEDashboardPage
const { useState, useEffect, useMemo } = React;

const API_BASE = "/api/v1" || "/api/v1";

const BLOOM_COLORS = {
  C1: { label: "Remember", bg: "bg-slate-400", light: "bg-slate-50", text: "text-slate-700" },
  C2: { label: "Understand", bg: "bg-blue-500", light: "bg-blue-50", text: "text-blue-700" },
  C3: { label: "Apply", bg: "bg-emerald-500", light: "bg-emerald-50", text: "text-emerald-700" },
  C4: { label: "Analyze", bg: "bg-amber-500", light: "bg-amber-50", text: "text-amber-700" },
  C5: { label: "Evaluate", bg: "bg-orange-500", light: "bg-orange-50", text: "text-orange-700" },
  C6: { label: "Create", bg: "bg-rose-500", light: "bg-rose-50", text: "text-rose-700" },
};

window.OBEDashboardPage = function OBEDashboardPage({ courseId = 4 }) {
  const [semester, setSemester] = useState("Spring-2026");
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(true);
  const [downloading, setDownloading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchAttainmentReport();
  }, [courseId, semester]);

  const fetchAttainmentReport = async () => {
    setLoading(true);
    setError(null);
    try {
      const token = localStorage.getItem("token");
      const res = await fetch(
        `${API_BASE}/courses/${courseId}/clo-attainment?semester=${encodeURIComponent(semester)}`,
        {
          headers: { Authorization: `Bearer ${token}` },
        }
      );
      if (res.ok) {
        const data = await res.json();
        setReport(data);
      } else {
        const errData = await res.json();
        setError(errData.detail || "Failed to load OBE attainment report.");
      }
    } catch (err) {
      console.error("Failed fetching OBE data:", err);
      setError("Network error while connecting to ProfessorOS analytics.");
    } finally {
      setLoading(false);
    }
  };

  const handleDownloadDossier = async () => {
    setDownloading(true);
    try {
      const token = localStorage.getItem("token");
      const res = await fetch(
        `${API_BASE}/courses/${courseId}/hec-dossier?semester=${encodeURIComponent(semester)}`,
        {
          headers: { Authorization: `Bearer ${token}` },
        }
      );

      if (!res.ok) {
        alert("Failed to compile HEC Dossier PDF.");
        return;
      }

      const blob = await res.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `HEC_Dossier_Course_${courseId}_${semester}.pdf`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (err) {
      console.error("Error downloading PDF:", err);
      alert("Error generating dossier download.");
    } finally {
      setDownloading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 pb-20 font-sans">
      {/* Header */}
      <header className="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-sm">
        <div className="max-w-7xl mx-auto px-6 py-4 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
          <div className="flex items-center gap-3">
            <span className="bg-emerald-600 text-white p-2.5 rounded-xl shadow-sm">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
            </span>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-xl font-bold text-slate-800">
                  OBE Accreditation & CLO Attainment
                </h1>
                <span className="text-xs font-semibold px-2.5 py-0.5 rounded-full bg-emerald-100 text-emerald-800 border border-emerald-300">
                  Washington Accord Tier-1
                </span>
              </div>
              <p className="text-xs text-slate-500">
                Continuous Quality Improvement (CQI) Matrix &bull; Pakistan Engineering Council (PEC) Standard
              </p>
            </div>
          </div>

          {/* Controls & Export */}
          <div className="flex items-center gap-3">
            <select
              value={semester}
              onChange={(e) => setSemester(e.target.value)}
              className="text-xs bg-slate-100 border border-slate-300 rounded-lg px-3 py-2 text-slate-700 font-medium focus:outline-none focus:ring-2 focus:ring-emerald-500"
            >
              <option value="Spring-2026">Spring 2026</option>
              <option value="Fall-2025">Fall 2025</option>
              <option value="Spring-2025">Spring 2025</option>
            </select>

            <button
              onClick={handleDownloadDossier}
              disabled={downloading}
              className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-medium rounded-lg shadow-sm transition-all flex items-center gap-2"
            >
              {downloading ? (
                <>
                  <svg className="animate-spin h-3.5 w-3.5 text-white" viewBox="0 0 24 24" fill="none">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
                  </svg>
                  Compiling PDF...
                </>
              ) : (
                <>
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  Export HEC Dossier (PDF)
                </>
              )}
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-6 py-6 space-y-6">
        {loading ? (
          <div className="flex flex-col items-center justify-center h-64 text-slate-400 gap-3">
            <svg className="animate-spin h-8 w-8 text-emerald-500" viewBox="0 0 24 24" fill="none">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
            </svg>
            <span className="text-sm font-medium">Computing cohort-level CLO attainment...</span>
          </div>
        ) : error ? (
          <div className="bg-rose-50 border border-rose-200 text-rose-800 p-6 rounded-2xl text-center">
            <p className="font-semibold text-sm">{error}</p>
            <button
              onClick={fetchAttainmentReport}
              className="mt-3 px-4 py-1.5 bg-rose-600 text-white text-xs rounded-lg font-medium"
            >
              Retry
            </button>
          </div>
        ) : report ? (
          <>
            {/* KPI Summary Banner */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div className="bg-white border border-slate-200 p-5 rounded-xl shadow-sm">
                <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block">
                  Course
                </span>
                <span className="text-lg font-bold text-slate-800 mt-1 block">
                  {report.course_code || `Course #${courseId}`}
                </span>
                <span className="text-xs text-slate-500 truncate block">
                  {report.course_title || "Advanced Operating Systems"}
                </span>
              </div>

              <div className="bg-white border border-slate-200 p-5 rounded-xl shadow-sm">
                <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block">
                  Enrolled Cohort
                </span>
                <span className="text-2xl font-bold text-slate-800 mt-1 block font-mono">
                  {report.total_students || 0}
                </span>
                <span className="text-xs text-slate-500">Students Evaluated</span>
              </div>

              <div className="bg-white border border-slate-200 p-5 rounded-xl shadow-sm">
                <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block">
                  Overall Attainment Average
                </span>
                <span className="text-2xl font-bold text-emerald-700 mt-1 block font-mono">
                  {report.overall_attainment_pct?.toFixed(1) || "0.0"}%
                </span>
                <span className="text-xs text-slate-500">Benchmark: 60.0% Minimum</span>
              </div>

              <div className="bg-white border border-slate-200 p-5 rounded-xl shadow-sm flex flex-col justify-between">
                <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block">
                  HEC Accreditation Status
                </span>
                <div className="mt-1">
                  <span
                    className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold border ${
                      report.accreditation_ready
                        ? "bg-emerald-50 text-emerald-800 border-emerald-300"
                        : "bg-amber-50 text-amber-800 border-amber-300"
                    }`}
                  >
                    <span
                      className={`w-2 h-2 rounded-full ${
                        report.accreditation_ready ? "bg-emerald-500" : "bg-amber-500"
                      }`}
                    />
                    {report.accreditation_ready ? "COMPLIANT / READY" : "CQI ACTION REQUIRED"}
                  </span>
                </div>
                <span className="text-[11px] text-slate-400 mt-2">
                  Criterion 3: Student Learning Outcomes
                </span>
              </div>
            </div>

            {/* CLO Attainment Matrix Table */}
            <div className="bg-white border border-slate-200 rounded-xl shadow-sm overflow-hidden">
              <div className="p-5 border-b border-slate-100 flex items-center justify-between">
                <div>
                  <h2 className="text-sm font-bold text-slate-800">
                    Course Learning Outcomes (CLO) Attainment Breakdown
                  </h2>
                  <p className="text-xs text-slate-500">
                    Calculated via student assessment scores mapped to cognitive competencies
                  </p>
                </div>
                <span className="text-xs font-mono text-slate-400">
                  Semester: {report.semester}
                </span>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs">
                  <thead className="bg-slate-50 text-slate-500 uppercase tracking-wider font-semibold border-b border-slate-200 text-[11px]">
                    <tr>
                      <th className="py-3.5 px-4">CLO Code</th>
                      <th className="py-3.5 px-4">Statement / Description</th>
                      <th className="py-3.5 px-4 text-center">Target KPI</th>
                      <th className="py-3.5 px-4">Actual Cohort Attainment</th>
                      <th className="py-3.5 px-4 text-center">Status</th>
                      <th className="py-3.5 px-4">CQI Action Plan</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {report.clos && report.clos.length > 0 ? (
                      report.clos.map((clo) => {
                        const pct = clo.attainment_percentage || 0;
                        const target = clo.target_percentage || 60;
                        const isMet = pct >= target;

                        return (
                          <tr key={clo.clo_id} className="hover:bg-slate-50/70 transition-colors">
                            <td className="py-4 px-4 font-mono font-bold text-indigo-700 whitespace-nowrap">
                              {clo.clo_code}
                            </td>
                            <td className="py-4 px-4 font-medium text-slate-700 max-w-sm">
                              {clo.description}
                            </td>
                            <td className="py-4 px-4 text-center font-mono font-semibold text-slate-600">
                              {target}%
                            </td>
                            <td className="py-4 px-4 min-w-[200px]">
                              <div className="flex items-center gap-3">
                                <div className="flex-1 bg-slate-100 rounded-full h-2.5 overflow-hidden">
                                  <div
                                    style={{ width: `${Math.min(100, pct)}%` }}
                                    className={`h-full rounded-full ${
                                      isMet ? "bg-emerald-500" : "bg-amber-500"
                                    }`}
                                  />
                                </div>
                                <span
                                  className={`font-mono font-bold text-xs ${
                                    isMet ? "text-emerald-700" : "text-amber-700"
                                  }`}
                                >
                                  {pct.toFixed(1)}%
                                </span>
                              </div>
                            </td>
                            <td className="py-4 px-4 text-center">
                              <span
                                className={`px-2.5 py-1 rounded-full text-[11px] font-bold border ${
                                  isMet
                                    ? "bg-emerald-50 text-emerald-800 border-emerald-200"
                                    : "bg-amber-50 text-amber-800 border-amber-200"
                                }`}
                              >
                                {isMet ? "MET ✓" : "GAP ⚠"}
                              </span>
                            </td>
                            <td className="py-4 px-4 text-slate-600 text-[11px] max-w-xs leading-relaxed">
                              {clo.cqi_action || "Target attained; maintain rigorous formative evaluations."}
                            </td>
                          </tr>
                        );
                      })
                    ) : (
                      <tr>
                        <td colSpan="6" className="text-center py-8 text-slate-400 text-xs">
                          No CLO mappings found for this assessment session.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Cognitive Balance & Bloom's Taxonomy Spectrum */}
            <div className="bg-white border border-slate-200 rounded-xl shadow-sm p-6">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-bold text-slate-800">
                    Bloom's Taxonomy Cognitive Distribution
                  </h3>
                  <p className="text-xs text-slate-500">
                    Cognitive rigor breakdown ensuring higher-order synthesis and analysis
                  </p>
                </div>
                <div className="flex items-center gap-3 text-xs">
                  <span className="flex items-center gap-1.5 text-slate-600">
                    <span className="w-2.5 h-2.5 rounded-full bg-emerald-500" />
                    Application & Analysis (&ge;30%)
                  </span>
                  <span className="flex items-center gap-1.5 text-slate-600">
                    <span className="w-2.5 h-2.5 rounded-full bg-slate-400" />
                    Recall (&le;30%)
                  </span>
                </div>
              </div>

              {/* Cognitive Distribution Bars */}
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-3">
                {Object.keys(BLOOM_COLORS).map((lvl) => {
                  const info = BLOOM_COLORS[lvl];
                  const pct = report.bloom_distribution ? report.bloom_distribution[lvl] || 0 : 0;
                  return (
                    <div
                      key={lvl}
                      className={`p-3.5 rounded-xl border border-slate-200 ${info.light} flex flex-col justify-between`}
                    >
                      <div className="flex items-center justify-between mb-2">
                        <span className={`text-xs font-bold ${info.text}`}>{lvl}</span>
                        <span className="text-[10px] text-slate-400">{info.label}</span>
                      </div>
                      <div className="text-xl font-bold font-mono text-slate-800 mb-2">
                        {parseFloat(pct).toFixed(0)}%
                      </div>
                      <div className="h-1.5 w-full bg-slate-200 rounded-full overflow-hidden">
                        <div
                          style={{ width: `${pct}%` }}
                          className={`h-full ${info.bg}`}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Continuous Quality Improvement Recommendations */}
            <div className="bg-gradient-to-r from-slate-900 to-indigo-950 text-white rounded-2xl p-6 shadow-md">
              <div className="flex items-center gap-3 mb-3">
                <span className="bg-indigo-500/20 text-indigo-300 p-2 rounded-lg border border-indigo-400/30">
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                </span>
                <h3 className="text-sm font-bold text-white tracking-wide">
                  Automated Continuous Quality Improvement (CQI) Directive
                </h3>
              </div>
              <p className="text-xs text-slate-300 leading-relaxed max-w-3xl">
                {report.cqi_summary ||
                  "All mapped Course Learning Outcomes satisfy the 60% cohort KPI threshold. For upcoming cohorts, maintain rubric-anchored question calibration and introduce open-ended concurrency case analyses."}
              </p>
            </div>
          </>
        ) : null}
      </main>
    </div>
  );
}
