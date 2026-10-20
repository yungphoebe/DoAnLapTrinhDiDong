let detector;
self.onmessage = async ({data}) => {
  try {
    if (data.type === 'init') {
      // Classic worker is needed by the bundled WASM loader's importScripts/global ModuleFactory.
      const { FilesetResolver, PoseLandmarker } = await import('./pose-assets/vision_bundle.mjs');
      const files = await FilesetResolver.forVisionTasks(new URL('./pose-assets', self.location.href).href);
      detector = await PoseLandmarker.createFromOptions(files, {
        baseOptions: {modelAssetPath:new URL('./pose-assets/pose_landmarker_lite.task',self.location.href).href, delegate:'CPU'},
        runningMode:'VIDEO', numPoses:1, minPoseDetectionConfidence:.6,
        minPosePresenceConfidence:.6, minTrackingConfidence:.6,
      });
      self.postMessage({type:'ready'});
    } else if (data.type === 'frame') {
      try {
        const result = detector.detectForVideo(data.frame, data.timestamp);
        self.postMessage({type:'pose', landmarks:result.landmarks[0] ?? [], timestamp:data.timestamp,
          width:data.frame.width,height:data.frame.height});
      } finally { data.frame.close(); }
    }
  } catch (error) {
    self.postMessage({type:'error',message:String(error)});
  }
};
