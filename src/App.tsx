import { useState, useEffect } from 'react';
import { 
  ShieldAlert, 
  History, 
  Plus, 
  ChevronLeft, 
  Loader2, 
  Microscope,
  Info,
  Database,
  LogOut
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { CameraCapture } from './components/CameraCapture';
import { AnalysisResult } from './components/AnalysisResult';
import { HistoryList } from './components/HistoryList';
import { Login } from './components/Login';
import { BallisticAnalysis, AnalysisState } from './types';
import { analyzeBallisticImage } from './services/gemini';

export default function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [user, setUser] = useState<string | null>(null);
  const [view, setView] = useState<'home' | 'analysis' | 'history'>('home');
  const [history, setHistory] = useState<BallisticAnalysis[]>([]);
  const [state, setState] = useState<AnalysisState>({
    isAnalyzing: false,
    currentAnalysis: null,
    error: null
  });

  // Check for existing session
  useEffect(() => {
    const session = localStorage.getItem('caliberia_session');
    if (session) {
      setIsAuthenticated(true);
      setUser(session);
    }
  }, []);

  // Load history from localStorage
  useEffect(() => {
    if (isAuthenticated) {
      const saved = localStorage.getItem('caliberia_history');
      if (saved) {
        try {
          setHistory(JSON.parse(saved));
        } catch (e) {
          console.error("Failed to parse history", e);
        }
      }
    }
  }, [isAuthenticated]);

  // Save history to localStorage
  useEffect(() => {
    if (isAuthenticated) {
      localStorage.setItem('caliberia_history', JSON.stringify(history));
    }
  }, [history, isAuthenticated]);

  const handleLogin = (email: string) => {
    setIsAuthenticated(true);
    setUser(email);
    localStorage.setItem('caliberia_session', email);
  };

  const handleLogout = () => {
    setIsAuthenticated(false);
    setUser(null);
    localStorage.removeItem('caliberia_session');
    setView('home');
  };

  const handleCapture = async (base64: string) => {
    setState({ isAnalyzing: true, currentAnalysis: null, error: null });
    setView('analysis');

    try {
      const results = await analyzeBallisticImage(base64);
      
      const newAnalysis: BallisticAnalysis = {
        id: Math.random().toString(36).substring(2, 11),
        timestamp: Date.now(),
        imageUrl: base64,
        results,
        notes: ''
      };

      setState({ isAnalyzing: false, currentAnalysis: newAnalysis, error: null });
      setHistory(prev => [newAnalysis, ...prev]);
    } catch (err) {
      setState({ 
        isAnalyzing: false, 
        currentAnalysis: null, 
        error: 'Error al procesar la imagen. Asegúrese de que sea una foto clara de una bala o cartucho.' 
      });
    }
  };

  const handleSaveNotes = (notes: string) => {
    if (state.currentAnalysis) {
      const updated = { ...state.currentAnalysis, notes };
      setState(prev => ({ ...prev, currentAnalysis: updated }));
      setHistory(prev => prev.map(item => item.id === updated.id ? updated : item));
    }
  };

  const handleDeleteHistory = (id: string) => {
    setHistory(prev => prev.filter(item => item.id !== id));
    if (state.currentAnalysis?.id === id) {
      setState({ isAnalyzing: false, currentAnalysis: null, error: null });
      setView('home');
    }
  };

  if (!isAuthenticated) {
    return <Login onLogin={handleLogin} />;
  }

  return (
    <div className="min-h-screen bg-zinc-950 technical-grid flex flex-col items-center">
      {/* Header */}
      <header className="w-full max-w-2xl px-6 py-8 flex items-center justify-between border-b border-zinc-900 bg-zinc-950/50 backdrop-blur-xl sticky top-0 z-40">
        <div className="flex items-center gap-3">
          <div className="p-2 bg-emerald-500 rounded-lg shadow-lg shadow-emerald-500/20">
            <ShieldAlert className="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 className="text-xl font-bold tracking-tight text-white">CaliberIA</h1>
            <p className="text-[10px] font-mono text-emerald-500 uppercase tracking-widest">Agente: {user?.split('@')[0]}</p>
          </div>
        </div>
        
        <div className="flex items-center gap-2">
          {view !== 'home' && (
            <button 
              onClick={() => setView('home')}
              className="p-2 text-zinc-400 hover:text-white transition-colors"
            >
              <Plus className="w-5 h-5" />
            </button>
          )}
          <button 
            onClick={() => setView('history')}
            className={`p-2 transition-colors ${view === 'history' ? 'text-emerald-500' : 'text-zinc-400 hover:text-white'}`}
          >
            <History className="w-5 h-5" />
          </button>
          <button 
            onClick={handleLogout}
            className="p-2 text-zinc-600 hover:text-red-500 transition-colors ml-2"
          >
            <LogOut className="w-5 h-5" />
          </button>
        </div>
      </header>

      <main className="w-full max-w-2xl px-6 py-8 flex-grow">
        <AnimatePresence mode="wait">
          {view === 'home' && (
            <motion.div
              key="home"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              className="space-y-8"
            >
              <div className="p-8 bg-zinc-900/30 border border-zinc-800 rounded-3xl space-y-4">
                <div className="flex items-center gap-3 text-emerald-500">
                  <Microscope className="w-6 h-6" />
                  <h2 className="text-lg font-bold">Nuevo Análisis</h2>
                </div>
                <p className="text-zinc-400 text-sm leading-relaxed">
                  Capture o suba una imagen de alta resolución de la munición para iniciar el procesamiento balístico automatizado.
                </p>
                <CameraCapture onCapture={handleCapture} />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="p-6 bg-zinc-900/30 border border-zinc-800 rounded-3xl space-y-2">
                  <Database className="w-5 h-5 text-zinc-500" />
                  <div className="text-2xl font-mono font-bold text-white">{history.length}</div>
                  <div className="text-[10px] text-zinc-500 uppercase font-bold tracking-widest">Registros</div>
                </div>
                <div className="p-6 bg-zinc-900/30 border border-zinc-800 rounded-3xl space-y-2">
                  <Info className="w-5 h-5 text-zinc-500" />
                  <div className="text-xs text-zinc-400 leading-tight">Modelo entrenado para calibres comunes y marcas globales.</div>
                </div>
              </div>
            </motion.div>
          )}

          {view === 'analysis' && (
            <motion.div
              key="analysis"
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              className="space-y-6"
            >
              <button 
                onClick={() => setView('home')}
                className="flex items-center gap-2 text-zinc-500 hover:text-white transition-colors text-sm font-medium"
              >
                <ChevronLeft className="w-4 h-4" />
                Volver
              </button>

              {state.isAnalyzing ? (
                <div className="flex flex-col items-center justify-center py-20 space-y-6">
                  <div className="relative">
                    <Loader2 className="w-16 h-16 text-emerald-500 animate-spin" />
                    <div className="absolute inset-0 flex items-center justify-center">
                      <div className="w-2 h-2 bg-emerald-500 rounded-full animate-ping" />
                    </div>
                  </div>
                  <div className="text-center space-y-2">
                    <h3 className="text-lg font-bold text-white">Procesando Evidencia</h3>
                    <p className="text-sm text-zinc-500 font-mono">Analizando patrones balísticos...</p>
                  </div>
                </div>
              ) : state.error ? (
                <div className="p-8 bg-red-500/10 border border-red-500/20 rounded-3xl text-center space-y-4">
                  <ShieldAlert className="w-12 h-12 text-red-500 mx-auto" />
                  <p className="text-red-200 text-sm">{state.error}</p>
                  <button 
                    onClick={() => setView('home')}
                    className="px-6 py-2 bg-red-500 text-white rounded-xl text-sm font-bold"
                  >
                    Reintentar
                  </button>
                </div>
              ) : state.currentAnalysis && (
                <AnalysisResult 
                  analysis={state.currentAnalysis} 
                  onSaveNotes={handleSaveNotes}
                />
              )}
            </motion.div>
          )}

          {view === 'history' && (
            <motion.div
              key="history"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: 20 }}
              className="space-y-6"
            >
              <div className="flex items-center justify-between">
                <h2 className="text-xl font-bold text-white">Historial Forense</h2>
                <button 
                  onClick={() => setView('home')}
                  className="text-sm text-zinc-500 hover:text-white transition-colors"
                >
                  Cerrar
                </button>
              </div>
              <HistoryList 
                history={history} 
                onSelect={(item) => {
                  setState({ isAnalyzing: false, currentAnalysis: item, error: null });
                  setView('analysis');
                }}
                onDelete={handleDeleteHistory}
              />
            </motion.div>
          )}
        </AnimatePresence>
      </main>

      <footer className="w-full max-w-2xl px-6 py-8 border-t border-zinc-900 text-center">
        <p className="text-[10px] text-zinc-600 font-mono uppercase tracking-[0.2em]">
          CaliberIA v1.0.0 // Investigación Académica // 2026
        </p>
      </footer>
    </div>
  );
}
