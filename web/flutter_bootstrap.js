{{flutter_js}}
{{flutter_build_config}}

async function startFineTime() {
  // Flutter's legacy service worker can keep an old app shell alive after a deploy.
  // Remove only Flutter's own worker, never unrelated site workers.
  if ('serviceWorker' in navigator) {
    try {
      const registrations = await navigator.serviceWorker.getRegistrations();
      await Promise.all(
        registrations
            .filter((registration) {
              const scriptUrl =
                  registration.active?.scriptURL ??
                  registration.installing?.scriptURL ??
                  registration.waiting?.scriptURL ??
                  '';
              return scriptUrl.includes('/flutter_service_worker.js');
            })
            .map((registration) => registration.unregister()),
      );
    } catch (_) {
      // Service-worker cleanup is best effort.
    }
  }

  _flutter.loader.load();
}

startFineTime();
