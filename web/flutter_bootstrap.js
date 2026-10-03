{{flutter_js}}
{{flutter_build_config}}

// Use Flutter's supported initialization flow directly.
// Keeping this bootstrap minimal avoids browser-side startup failures before Dart runs.
_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    const splash = document.getElementById('loading-splash');
    if (splash) {
      splash.style.opacity = '0';
      setTimeout(function() {
        if (splash.parentNode) splash.parentNode.removeChild(splash);
      }, 400);
    }
    await appRunner.runApp();
  }
});
