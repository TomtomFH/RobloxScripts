@echo off
echo Pulling latest changes...
git pull
echo Done!

echo Staging all changes...
git add .
echo Done!

echo Committing changes...
set /p message=Commit message: 
git commit -m "%message%"
echo Done!

echo Pushing to remote...
git push

echo Done!
echo You can close or press any key to exit.
pause >nul
