

## Strict Rule from User
When adding new features (like Phase 3 Courses), DO NOT break or modify existing working features (Notes, Home, AI, Community, Profile). Keep the old code intact to avoid unexpected errors.

## GitHub Auto-Commit Rule
After EVERY code change or feature addition, you MUST automatically:
1. Run `git add -A -- . ":(exclude)studysphere-web"` to stage all changes
2. Run `git commit -m "descriptive commit message"` with a clear description of what changed
3. Run `git pull origin master --no-rebase` to sync with remote first
4. Run `git push origin master` to push to GitHub

Do NOT ask for permission — just do it automatically after every task.
The remote is: https://github.com/vishal009vb/studysphere.git (branch: master)

