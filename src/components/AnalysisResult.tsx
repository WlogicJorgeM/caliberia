import React from 'react';
import { BallisticAnalysis } from '../types';
import { Target, Shield, Ruler, Info, Tag, Calendar, FileText } from 'lucide-react';
import { motion } from 'motion/react';

interface AnalysisResultProps {
  analysis: BallisticAnalysis;
  onSaveNotes: (notes: string) => void;
}

export const AnalysisResult: React.FC<AnalysisResultProps> = ({ analysis, onSaveNotes }) => {
  const { results } = analysis;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="space-y-6"
    >
      <div className="relative aspect-video rounded-2xl overflow-hidden border border-zinc-800">
        <img src={analysis.imageUrl} alt="Analysis Target" className="w-full h-full object-cover" />
        <div className="absolute inset-0 bg-gradient-to-t from-zinc-950/80 to-transparent" />
        <div className="absolute bottom-4 left-4 flex items-center gap-2">
          <div className="px-3 py-1 bg-emerald-500 text-white text-xs font-bold rounded-full uppercase tracking-wider">
            Identificado
          </div>
          <div className="px-3 py-1 bg-white/10 backdrop-blur-md text-white text-xs font-medium rounded-full">
            Confianza: {(results.confidence * 100).toFixed(1)}%
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <DataCard
          icon={<Target className="w-5 h-5 text-emerald-500" />}
          label="Calibre Estimado"
          value={results.caliber}
        />
        <DataCard
          icon={<Shield className="w-5 h-5 text-emerald-500" />}
          label="Tipo de Munición"
          value={results.ammoType}
        />
        <DataCard
          icon={<Info className="w-5 h-5 text-emerald-500" />}
          label="Arma Compatible"
          value={results.compatibleWeapon}
        />
        <DataCard
          icon={<Ruler className="w-5 h-5 text-emerald-500" />}
          label="Longitud Estimada"
          value={results.estimatedLength}
        />
      </div>

      <div className="p-6 bg-zinc-900/50 border border-zinc-800 rounded-2xl space-y-4">
        <div className="flex items-center gap-2 text-zinc-400">
          <Tag className="w-4 h-4" />
          <span className="text-xs font-bold uppercase tracking-widest">Posibles Fabricantes</span>
        </div>
        <div className="flex flex-wrap gap-2">
          {results.possibleBrands.map((brand, i) => (
            <span key={i} className="px-3 py-1 bg-zinc-800 text-zinc-300 text-sm rounded-lg border border-zinc-700">
              {brand}
            </span>
          ))}
        </div>
      </div>

      <div className="p-6 bg-zinc-900/50 border border-zinc-800 rounded-2xl space-y-4">
        <div className="flex items-center gap-2 text-zinc-400">
          <FileText className="w-4 h-4" />
          <span className="text-xs font-bold uppercase tracking-widest">Notas de Investigación</span>
        </div>
        <textarea
          defaultValue={analysis.notes}
          onChange={(e) => onSaveNotes(e.target.value)}
          placeholder="Agregar observaciones forenses..."
          className="w-full h-32 bg-zinc-950 border border-zinc-800 rounded-xl p-4 text-zinc-300 focus:outline-none focus:border-emerald-500 transition-colors resize-none"
        />
      </div>

      <div className="flex items-center justify-between text-zinc-500 text-xs font-mono px-2">
        <div className="flex items-center gap-1">
          <Calendar className="w-3 h-3" />
          {new Date(analysis.timestamp).toLocaleString()}
        </div>
        <div>ID: {analysis.id}</div>
      </div>
    </motion.div>
  );
};

const DataCard = ({ icon, label, value }: { icon: React.ReactNode, label: string, value: string }) => (
  <div className="p-4 bg-zinc-900/50 border border-zinc-800 rounded-2xl flex items-start gap-4">
    <div className="p-2 bg-zinc-950 rounded-xl border border-zinc-800">
      {icon}
    </div>
    <div>
      <div className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest mb-1">{label}</div>
      <div className="text-lg font-mono text-zinc-100">{value}</div>
    </div>
  </div>
);
