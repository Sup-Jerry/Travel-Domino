# Cleanup Rules

## Safe directory names

Delete candidates when file path contains one of these directory segments:

- `node_modules`
- `dist`
- `build`
- `out`
- `target`
- `coverage`
- `.next`
- `.nuxt`
- `.cache`
- `.turbo`
- `.parcel-cache`
- `.gradle`
- `tmp`
- `temp`
- `logs`

## Safe file extensions

Delete candidates when extension matches:

- `.log`
- `.tmp`
- `.temp`
- `.cache`
- `.bak`
- `.old`
- `.dmp`

## Protections

- Never scan inside `.git`, `.svn`, `.hg`.
- If Git repo detected, never delete files returned by `git ls-files`.
- Minimum file size default is `20 MB` to avoid noisy small-file deletion.
