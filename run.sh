git pull;

if [ ! -z "$1" ]; then
    module load vcs;
fi

make;