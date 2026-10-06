{{flutter_js}}
{{flutter_build_config}}

// Use Flutter's standard loader path and force single-threaded skwasm
// where SharedArrayBuffer/cross-origin isolation is unavailable (such as
// normal GitHub Pages hosting). Flutter then starts the app normally and the
// index.html first-frame listener removes the splash after the first frame.
_flutter.loader.load({
  config: {
    forceSingleThreadedSkwasm: true,
  },
});
