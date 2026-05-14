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

int main()
{
    UNI *students = new UNI[3]{

    }

    return 0;
}

UNI::UNI(const char * newam, const char * newname)
{
    if(newam!=nullptr)
    {
        am = new char [strlen(newam)+1];
        strcpy(am,newam);
    }
    else{
        cout<<"Try other AM"<<endl;
        am=nullptr;
    }
    
    if(newname!=nullptr){
        name = new char [strlen(newname)+1];
        strcpy(name,newname);
    }
    else{
        cout<<"Try another name"<<endl;
        name=nullptr;
    }

    ismale=1;
    sem=1;
}

UNI::UNI(const char *newam, const char *newname, bool gender, unsigned int newsem)
{
    if(newam!=nullptr)
    {
        am = new char [strlen(newam)+1];
        strcpy(am,newam);
    }
    else{
        cout<<"Try other AM"<<endl;
        am=nullptr;
    }

    if(newname!=nullptr)
    {
        name = new char [strlen(newname)+1];
        strcpy(name,newname);
    }
    else{
        cout<<"Try another name"<<endl;
        name=nullptr;
    }

    if(gender==0 || gender==1)
    {
        ismale=gender;
    }
    else{
        cout<<"The gender must be 1 for male 0 for female";
    }

    sem=newsem;
}

UNI::UNI(const UNI &ob)
{
    if(ob.am!=nullptr)
    {
        am=new char [strlen(ob.am)+1];
        strcpy(am,ob.am);
    }else{
        cout<<"Try other AM"<<endl;
        am=nullptr;
    }

    if(ob.name!=nullptr)
    {
        name = new char [strlen(obname)+1];
        strcpy(name,ob.name);
    }else{
        cout<<"Try other name";
        name=nullptr;
    }

    if(ob.gender==0 || ob.gender==1)
    {
        ismale=ob.ismale;
    }
    else{
        cout<<"The gender must be 1 for male 0 for female";
    }

    sem=ob.sem;
}