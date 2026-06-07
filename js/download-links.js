// Point each platform download button at the latest LensHH-LT release
// asset, resolved at page load from the GitHub API. Asset filenames carry
// the version (e.g. LensHH-LT-Setup-1.0.118.exe), so we match by pattern
// instead of hardcoding a version that would go stale every release.
//
// Each button keeps a default href of the releases page, so with no JS
// (or if the API is rate-limited/unreachable) the user still lands on a
// working download. On success the href is upgraded to the direct file.
(function () {
  'use strict';
  var REPO = 'SynapseOptics/LensHH-LT';
  var targets = [
    { id: 'dl-windows', match: function (n) { return /\.exe$/i.test(n); } },
    { id: 'dl-linux',   match: function (n) { return /\.AppImage$/i.test(n); } },
    { id: 'dl-macos',   match: function (n) { return /osx-arm64.*\.zip$/i.test(n); } },
    { id: 'dl-pdf',     match: function (n) { return /UserGuide\.pdf$/i.test(n); } }
  ];

  fetch('https://api.github.com/repos/' + REPO + '/releases/latest', {
    headers: { Accept: 'application/vnd.github+json' }
  })
    .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
    .then(function (rel) {
      var assets = rel.assets || [];
      targets.forEach(function (t) {
        var el = document.getElementById(t.id);
        if (!el) return;
        var asset = assets.filter(function (a) { return t.match(a.name); })[0];
        if (asset) { el.href = asset.browser_download_url; }
      });
      var label = document.getElementById('dl-version');
      if (label && rel.tag_name) { label.textContent = rel.tag_name; }
    })
    .catch(function () { /* keep the default releases-page hrefs */ });
})();
