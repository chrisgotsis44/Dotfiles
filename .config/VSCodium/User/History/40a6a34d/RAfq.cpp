#include <iostream>
#include <cstring>
using namespace std;

class UNI{
    public:
        UNI(const char *newam, const char *newname);
        UNI(const char * newam, const char * newname, bool gender, unsigned int newsem);
        UNI(const STUD&ob);
        ~UNI();
        void testprint();
        char *getam();
        char *getname();
        bool getgender();
        unsigned int getsem();
        void setam(const char *newam);
        void setname(const char *newname);
        void setgender(bool newgender);
        void setsem(unsigned int newsem);

    private:
        char *am;
        char *name;
        bool ismale;
        unsigned int semester;
};