# Vice Avenue — Git setup (plain CMD, one command at a time)

Run these in CMD, inside the VICE_WORLD folder. Wait for each
command to finish before the next one.

```cmd
REM 1. Go into the project folder (adjust the path to your PC)
cd C:\path\to\VICE_WORLD

REM 2. Initialise the repository
git init

REM 3. Check what will be committed (verify: no .godot/, no export/,
REM    no .apk/.aab, no .keystore — if any appear, STOP and fix .gitignore)
git status

REM 4. Add everything
git add .

REM 5. First commit
git commit -m "VICE WORLD v1.0.0 skeleton — Ready to Build v4.0"

REM 6. Add the remote (REPLACE the URL with your repository URL;
REM    decide the owner/account first — ask before pushing)
git remote add origin https://github.com/OWNER/vice-world.git

REM 7. Rename the branch to main (if needed)
git branch -M main

REM 8. Push
git push -u origin main
```

Later pushes (after each verified milestone):

```cmd
git status
git add .
git commit -m "Phase 5: player controller with touch controls"
git push
```

Rules: one commit per verified milestone; never commit the
keystore or passwords; never commit `.godot/` or `export/`;
never force-push to main.
