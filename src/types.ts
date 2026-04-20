export interface BallisticAnalysis {
  id: string;
  timestamp: number;
  imageUrl: string;
  results: {
    caliber: string;
    ammoType: string;
    compatibleWeapon: string;
    estimatedLength: string;
    possibleBrands: string[];
    confidence: number;
    description: string;
  };
  notes: string;
}

export interface AnalysisState {
  isAnalyzing: boolean;
  currentAnalysis: BallisticAnalysis | null;
  error: string | null;
}
