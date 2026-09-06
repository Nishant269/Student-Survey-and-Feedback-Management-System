rvey-and-Feedback-Management-System'
hint: Updates were rejected because the remote contains work that you do not
hint: have locally. This is usually caused by another repository pushing to
hint: the same ref. If you want to integrate the remote changes, use
hint: 'git pull' before pushing again.
hint: See the 'Note about fast-forwards' in 'git push --help' for details.

E:\Nishant\Student-Survey-Feddback-Management-System-main\Student-Survey-Feddback-Management-System-main>git pull
remote: Enumerating objects: 3, done.
remote: Counting objects: 100% (3/3), done.
remote: Total 3 (delta 0), reused 0 (delta 0), pack-reused 0 (from 0)
Unpacking objects: 100% (3/3), 896 bytes | 224.00 KiB/s, done.
From https://github.com/Nishant269/Student-Survey-and-Feedback-Management-System
 * [new branch]      main       -> origin/main
There is no tracking information for the current branch.
Please specify which branch you want to merge with.
See git-pull(1) for details.

    git pull <remote> <branch>

If you wish to set tracking information for this branch you can do so with:

    git branch --set-upstream-to=origin/<branch> main


E:\Nishant\Student-Survey-Feddback-Management-System-main\Student-Survey-Feddback-Management-System-main>

E:\Nishant\Student-Survey-Feddback-Management-System-main\Student-Survey-Feddback-Management-System-main>git pull origin main --allow-unrelated-histories
From https://github.com/Nishant269/Student-Survey-and-Feedback-Management-System
 * branch            main       -> FETCH_HEAD
Merge made by the 'ort' strategy.
 README.md | 1 +
 1 file changed, 1 insertion(+)
 create mode 100644 README.md

E:\Nishant\Student-Survey-Feddback-Management-System-main\Student-Survey-Feddback-Management-System-main>git branch --set-upstream-to=origin/main main
branch 'main' set up to track 'origin/main'.

E:\Nishant\Student-Survey-Feddback-Management-System-main\Student-Survey-Feddback-Management-System-main>git push -u origin main
Enumerating objects: 47, done.
Counting objects: 100% (47/47), done.
Delta compression using up to 12 threads
Compressing objects: 100% (39/39), done.
Writing objects: 100% (46/46), 50.29 KiB | 4.57 MiB/s, done.
Total 46 (delta 21), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (21/21), done.
To https://github.com/Nishant269/Student-Survey-and-Feedback-Management-System
   7dca2f4..e8f336d  main -> main
branch 'main' set up to track 'origin/main'.

E:\Nishant\Student-Survey-Feddback-Management-System-main\Student-Survey-Feddback-Management-System-main>
