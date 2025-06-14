#!/bin/bash
# Fix git remote to use SSH instead of HTTPS

echo "Current git remote:"
git remote -v

echo ""
echo "Changing to SSH..."
git remote set-url origin git@github.com:jdpierce21/nas_mount.git

echo ""
echo "New git remote:"
git remote -v

echo ""
echo "Done! Git will now use SSH for authentication."