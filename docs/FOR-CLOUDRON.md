# For the Cloudron team: observations from packaging Cognee

Verified on a test box running Cloudron 10.0.5. Offered as things that would make the platform better for apps
that load machine-learning models. Nothing here is a complaint; each item says what was seen.

1. **A memory limit can be hit thousands of times with no OOM kill and no alert.** At a 4 GiB limit the app was
   never killed and answered health checks, yet `memory.events` showed `max` 3,997 times and `memory.swap.peak`
   2.23 GB. A user would only see a slow app. The dashboard's memory graph does not show limit hits or swap.
   A "this app is at its limit" indicator would catch this class of problem.
2. **`persistentDirs` is the right tool for re-downloadable model caches, and it works as documented**: kept across
   updates, left out of backups, untouched by a restore, empty and refilled on a clone. What is missing is a
   way for the manifest to say "this directory is a cache, say so in the backup size and the restore notes".
   The `checklist` field covered the user-facing half well.
3. **The CLI has no memory-limit flag for a standing app.** Changing it goes through the dashboard's own
   endpoint (`POST /api/v1/apps/<id>/configure/memory_limit`). A `cloudron configure --memory-limit` would help
   scripted installs.
4. **Images loaded straight into a box's Docker for testing lose their tag.** The platform prunes tags it does not
   consider in use, and the next reconfigure then fails with "No such image" and leaves the app in `error` until the
   tag is restored by image ID and the app repaired. Not an issue for registry installs.
5. **A community install fails outright when `packagerName` is empty**, and only at install time from a versions
   URL, so a package can install perfectly from an image and fail for every stranger. A check in
   `cloudron versions add` would catch it earlier.
6. **First boot of a heavy app is long.** About 48 seconds passed from process spawn to the backend serving, and one
   health probe was aborted in that window. A manifest field for a start-up grace period would remove the noise.
