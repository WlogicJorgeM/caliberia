import React from 'react';
import { BallisticAnalysis } from '../types';
import { Clock, ChevronRight, Trash2 } from 'lucide-react';
import { motion } from 'motion/react';

interface HistoryListProps {
  history: BallisticAnalysis[];
  onSelect: (analysis: BallisticAnalysis) => void;
  onDelete: (id: string) => void;
}

export const HistoryList: React.FC<HistoryListProps> = ({ history, onSelect, onDelete }) => {
  if (history.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-zinc-500">
        <Clock className="w-12 h-12 mb-4 opacity-20" />
        <p className="text-sm">No hay registros previos</p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {history.map((item) => (
        <motion.div
          key={item.id}
          initial={{ opacity: 0, x: -10 }}
          animate={{ opacity: 1, x: 0 }}
          className="group relative bg-zinc-900/50 border border-zinc-800 rounded-xl overflow-hidden hover:border-zinc-600 transition-all cursor-pointer"
          onClick={() => onSelect(item)}
        >
          <div className="flex items-center p-3 gap-4">
            <div className="w-16 h-16 rounded-lg overflow-hidden flex-shrink-0 border border-zinc-800">
              <img src={item.imageUrl} alt="" className="w-full h-full object-cover" />
            </div>
            <div className="flex-grow min-w-0">
              <div className="flex items-center justify-between mb-1">
                <span className="text-sm font-mono text-emerald-500 font-bold">{item.results.caliber}</span>
                <span className="text-[10px] text-zinc-500">{new Date(item.timestamp).toLocaleDateString()}</span>
              </div>
              <p className="text-xs text-zinc-400 truncate">{item.results.ammoType}</p>
              <p className="text-[10px] text-zinc-600 mt-1 uppercase tracking-tighter truncate">{item.results.compatibleWeapon}</p>
            </div>
            <div className="flex flex-col items-end gap-2">
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onDelete(item.id);
                }}
                className="p-2 text-zinc-600 hover:text-red-500 transition-colors"
              >
                <Trash2 className="w-4 h-4" />
              </button>
              <ChevronRight className="w-4 h-4 text-zinc-700 group-hover:text-zinc-400 transition-colors" />
            </div>
          </div>
        </motion.div>
      ))}
    </div>
  );
};
