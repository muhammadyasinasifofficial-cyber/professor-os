{{flutter_js}}
{{flutter_build_config}}

// Railway serves the web bundle directly from FastAPI. Keep PWA caching off so
// a new deployment is picked up without a stale service-worker shell.
_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  }
});
