{{flutter_js}}
{{flutter_build_config}}

async function startFineTime() {
  if ('serviceWorker' in navigator) {
    try {
      const registrations = await navigator.serviceWorker.getRegistrations();
      await Promise.all(
        registrations
          .filter((registration) => {
            const scriptUrl =
              registration.active?.scriptURL ??
              registration.installing?.scriptURL ??
              registration.waiting?.scriptURL ??
              '';
            return scriptUrl.includes('/flutter_service_worker.js');
          })
          .map((registration) => registration.unregister())
      );
    } catch (_) {
      // Best-effort cleanup
    }
  }

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
}

startFineTime();
