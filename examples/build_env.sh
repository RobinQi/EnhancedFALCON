virtualenv --no-site-packages  --always-copy   $PWD/fc_env
. $PWD/fc_env/bin/activate
git clone https://github.com/pb-jchin/pypeFLOW.git
cd pypeFLOW
python setup.py install

cd ..
git clone https://github.com/WangGenomicsLab/FALCON.git
cd FALCON
python setup.py install

cd ..
git clone https://github.com/pb-jchin/DAZZ_DB.git
cd DAZZ_DB/
make
cp DBrm DBshow DBsplit DBstats fasta2DB ../fc_env/bin/

cd ..
git clone https://github.com/pb-jchin/DALIGNER.git
cd DALIGNER
git checkout 97b0c27a26164dbdd6dc52923855501ca3d14d45
make
cp daligner daligner_p DB2Falcon HPCdaligner LA4Falcon LAmerge LAsort  ../fc_env/bin
cd ..
