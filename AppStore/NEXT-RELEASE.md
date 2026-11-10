# Next release: move the web addresses

On 2026-11-10 the code moved to **github.com/justpuzzles/justshikaku**. The old
repo **kkai/justshikaku** stays, only to serve the pages the live app and its App
Store listing point at. Don't delete it: that would take
kaikunze.de/justshikaku/ offline.

In the next release, once the app's page exists at justpuzzles.app/shikaku/
(see "Websites" in the workspace README):

- [ ] ASC version: Support URL and Marketing URL
      kaikunze.de/justshikaku/ → https://justpuzzles.app/shikaku/
- [ ] ASC App Information: Privacy Policy URL
      kaikunze.de/justshikaku/justshikaku-privacy.html → https://justpuzzles.app/shikaku/privacy/
- [ ] In-app links (Settings / About) that still say kaikunze.de/justshikaku/
- [ ] After that release is live: turn kkai/justshikaku's gh-pages into
      redirects to the new pages (old binaries keep their links), then
      archive kkai/justshikaku.

Local clones have two remotes: `origin` (justpuzzles, code) and `kaikunze`
(kkai, the old pages). Push code to `origin` only.
