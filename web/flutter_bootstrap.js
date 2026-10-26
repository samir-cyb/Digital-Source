{{flutter_js}}
{{flutter_build_config}}

const revision = document.querySelector('meta[name="ds-build"]')?.content || Date.now().toString();
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    const entrypoint = new URL(build.mainJsPath, document.baseURI);
    entrypoint.searchParams.set('build', revision);
    build.mainJsPath = entrypoint.toString();
  }
}
_flutter.loader.load();

