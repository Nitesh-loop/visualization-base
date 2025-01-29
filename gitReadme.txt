https://github.com/Nitesh-loop/web-project-react.git

#create a new project

# git setup:
git init
git remote add origin https://github.com/Nitesh-loop/web-project-react.git
git config user.email "nitesh166k@gmail.com"
git config user.name "Nitesh-loop"
git add .
git commit -m "Initial commit"
git push -u origin main

# Add GitHub Actions Workflow:
Create a .github/workflows directory in the root of your project, and within it, create a YAML file for your workflow, such as ci.yml.

# Commit and Push GitHub Actions Workflow:
git add .github/workflows/ci.yml
git commit -m "Add GitHub Actions workflow"
git push

# go to repo setting/pages
select the gh-pages in branch and save

# Add the homepage:
go to the react project and go to package.json:
add this line after "private"
"homepage": "https://nitesh-loop.github.io/web-project-react/",

# commit and push again



# Change the Git current worrking brach:

git branch
- The branch with a * next to it is your current branch

- To create a new branch and switch to it:
git checkout -b new-branch-name

# Stage and Commit Your Changes:
- Stage your changes:
git add .

- Or, for specific files:
git add file1 file2

- Commit your changes:
git commit -m "Your commit message"


# Push the New Branch (Optional, If Working with a Remote)
# If you are working with a remote repository (e.g., GitHub), push your new branch:  (i always do remote !!!)
git push origin new-branch-name

# Switch Back to the Main Branch:
# To switch back to the main branch:
- git checkout main

# Merge the New Branch into the Main Branch
# To merge the changes from your new branch into the main branch:
# First, make sure you're on the main branch:
git checkout main

- Merge the new branch into main:
git merge new-branch-name


# Push the Changes to the Remote Repository
git push origin main


# Always pull the latest changes from the main branch before merging:
git pull origin main


# Resolve merge conflicts (if any) during the merge. Git will highlight conflicts in the affected files. Fix them manually, then:
git add conflict-file
git commit

# Rebase instead of merge (optional): To maintain a linear commit history, you can rebase your branch onto main before merging:
git checkout new-branch-name
git rebase main
git checkout main
git merge new-branch-name


# Delete the branch after merging if it’s no longer needed:
git branch -d new-branch-name




--------------------------------------------------------------------------------------
# best alternative to merge

# Rebase Workflow (Step-by-Step)
# Switch to Your Feature Branch
# Make sure you're on your feature branch (e.g., new-branch-name):
git checkout new-branch-name

# Fetch the Latest Changes from main
# Before rebasing, make sure your local main branch is up to date:
git fetch origin
git checkout main
git pull origin main

# Rebase the Feature Branch onto main
# Now, rebase your feature branch onto the updated main branch:
git rebase main

Note: Git will replay your feature branch's commits on top of the latest main branch commits.
If there are conflicts, Git will pause the rebase and let you resolve them manually

# Resolve Conflicts (If Any)
# If there are conflicts:
# Git will stop and show a message like:
CONFLICT (content): Merge conflict in <file>

# Open the conflicting files and manually resolve the conflicts.

# Stage the resolved files:
git add <file>

# Continue the rebase:
git rebase --continue

# If you want to cancel the rebase process:
git rebase --abort

# Push the Rebased Feature Branch
# Since rebasing rewrites history, you'll need to force-push your rebased branch to the remote repository:
git push origin new-branch-name --force

# Merge the Feature Branch into main 
# Switch back to the main branch and perform a fast-forward merge
git checkout main
git merge new-branch-name

# Push the updated main branch:
git push origin main




