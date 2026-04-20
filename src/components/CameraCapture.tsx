import React, { useRef, useState } from 'react';
import { Camera, Upload, X, RefreshCw } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';

interface CameraCaptureProps {
  onCapture: (base64: string) => void;
}

export const CameraCapture: React.FC<CameraCaptureProps> = ({ onCapture }) => {
  const [isCameraOpen, setIsCameraOpen] = useState(false);
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [stream, setStream] = useState<MediaStream | null>(null);

  const startCamera = async () => {
    try {
      const mediaStream = await navigator.mediaDevices.getUserMedia({ 
        video: { facingMode: 'environment' } 
      });
      setStream(mediaStream);
      if (videoRef.current) {
        videoRef.current.srcObject = mediaStream;
      }
      setIsCameraOpen(true);
    } catch (err) {
      console.error("Error accessing camera:", err);
      alert("No se pudo acceder a la cámara.");
    }
  };

  const stopCamera = () => {
    if (stream) {
      stream.getTracks().forEach(track => track.stop());
      setStream(null);
    }
    setIsCameraOpen(false);
  };

  const takePhoto = () => {
    if (videoRef.current && canvasRef.current) {
      const context = canvasRef.current.getContext('2d');
      if (context) {
        canvasRef.current.width = videoRef.current.videoWidth;
        canvasRef.current.height = videoRef.current.videoHeight;
        context.drawImage(videoRef.current, 0, 0);
        const base64 = canvasRef.current.toDataURL('image/jpeg');
        onCapture(base64);
        stopCamera();
      }
    }
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        onCapture(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  return (
    <div className="w-full">
      <div className="grid grid-cols-2 gap-4">
        <button
          onClick={startCamera}
          className="flex flex-col items-center justify-center p-8 border-2 border-dashed border-zinc-800 rounded-2xl hover:border-emerald-500 hover:bg-emerald-500/5 transition-all group"
        >
          <Camera className="w-8 h-8 mb-2 text-zinc-400 group-hover:text-emerald-500" />
          <span className="text-sm font-medium text-zinc-400 group-hover:text-emerald-500">Cámara</span>
        </button>

        <label className="flex flex-col items-center justify-center p-8 border-2 border-dashed border-zinc-800 rounded-2xl hover:border-emerald-500 hover:bg-emerald-500/5 transition-all group cursor-pointer">
          <Upload className="w-8 h-8 mb-2 text-zinc-400 group-hover:text-emerald-500" />
          <span className="text-sm font-medium text-zinc-400 group-hover:text-emerald-500">Galería</span>
          <input type="file" accept="image/*" className="hidden" onChange={handleFileUpload} />
        </label>
      </div>

      <AnimatePresence>
        {isCameraOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-black flex flex-col items-center justify-center p-4"
          >
            <div className="relative w-full max-w-lg aspect-[3/4] bg-zinc-900 rounded-3xl overflow-hidden border border-zinc-800 shadow-2xl">
              <video
                ref={videoRef}
                autoPlay
                playsInline
                className="w-full h-full object-cover"
              />
              <div className="absolute inset-0 border-[40px] border-black/20 pointer-events-none">
                <div className="w-full h-full border border-emerald-500/30 relative">
                  <div className="absolute top-0 left-0 w-8 h-8 border-t-2 border-l-2 border-emerald-500" />
                  <div className="absolute top-0 right-0 w-8 h-8 border-t-2 border-r-2 border-emerald-500" />
                  <div className="absolute bottom-0 left-0 w-8 h-8 border-b-2 border-l-2 border-emerald-500" />
                  <div className="absolute bottom-0 right-0 w-8 h-8 border-b-2 border-r-2 border-emerald-500" />
                  <div className="scan-line" />
                </div>
              </div>
              
              <div className="absolute bottom-8 left-0 right-0 flex justify-center gap-6 px-4">
                <button
                  onClick={stopCamera}
                  className="p-4 bg-zinc-800/80 backdrop-blur-md rounded-full text-white hover:bg-zinc-700 transition-colors"
                >
                  <X className="w-6 h-6" />
                </button>
                <button
                  onClick={takePhoto}
                  className="p-6 bg-emerald-500 rounded-full text-white shadow-lg shadow-emerald-500/20 hover:bg-emerald-400 transition-colors"
                >
                  <Camera className="w-8 h-8" />
                </button>
                <div className="w-14" /> {/* Spacer */}
              </div>
            </div>
            <canvas ref={canvasRef} className="hidden" />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};
