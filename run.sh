git pull;

if [ ! -z "$1" ]; then
    module load vcs;
else
    echo "no need to load vcs";
fi

make simv;