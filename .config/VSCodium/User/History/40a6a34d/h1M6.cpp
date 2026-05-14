#include <iostream>
#include <cstring>
using namespace std;

class UNI{
    public:
        UNI(const char *newam, const char *newname);
        UNI(const char * newam, const char * newname, bool gender, unsigned int newsem);
        UNI(const UNI&ob);
        ~UNI();
        void setam(const char *newam);
        void setname(const char *newname);
        void setgender(bool newgender);
        void setsem(unsigned int newsem);
        char *getam();
        char *getname();
        bool getgender();
        unsigned int getsem();
        void print(ostream& os) const;
        UNI& operator++();
        UNI operator++(int);                
        UNI& operator+=(unsigned int value);  
        UNI& operator-=(unsigned int value);  
        UNI& operator-();

    private:
        char *am;
        char *name;
        bool ismale;
        unsigned int sem;
};

int main()
{
    //Arxikopoiisi ton foititon
    UNI *students = new UNI[3]{
        UNI("1000", "Νικος Μπολμποτσευκας", true, 3),
        UNI("1001", "Donald Trump"),
        UNI("1002", Μαρια Παπαδοπουλου, false, 1)
    };

    //Ektipwsi ton foititon
    students[0].print(cout);
    students[1].print(cout);
    students[2].print(cout);
    cout<<endl;

    //Allages
    ++students[0];
    students[0].print(cout);
    cout<<endl;

    students[2]++;
    students[2].print(cout);
    cout<<endl;

    -students[0];
    students[0].print(cout);
    cout<<endl;

    students[1] += 3;
    students[1].print(cout);

    delete[] students;

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

    if(gender==true || gender==false)
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
        name = new char [strlen(ob.name)+1];
        strcpy(name,ob.name);
    }else{
        cout<<"Try other name";
        name=nullptr;
    }

    if(ob.gender==true || ob.gender==false)
    {
        ismale=ob.ismale;
    }
    else{
        cout<<"The gender must be 1 for male 0 for female";
    }

    sem=ob.sem;
}

UNI::~UNI(){
    delete[] am;
    delete[] name;
}

void UNI::setam(const char *newam)
{
    delete[] am;

    if(newam!=nullptr)
    {
        am=new char [strlen(newam)+1];
        strcpy(am,newam);
    }else{
        cout<<"Try other AM"<<endl;
        am=nullptr;
    }
}

void UNI::setname(const char *newname)
{
    delete[] name;

    if(newname!=nullptr)
    {
            name=new char [strlen(newname)+1];
            strcpy(name,newname);
    }else{
        cout<<"Try other name"<<endl;
        name=nullptr;
    }
}

void UNI::setgender(bool newgender){
    ismale=newgender;
}

void UNI::setsem(unsigned int newsem){
    sem=newsem;
}

char *UNI::getam(){
    return am;
}

char *UNI::getname(){
    return name;
}

bool UNI::getgender(){
    return ismale;
}

unsigned int UNI::getsem(){
    return sem;
}

void UNI::print(ostream& os) const {
    os << "AM: " << am 
    << " Ονοματεπώνυμο: " << name << " (" << strlen(name) + 1 << ")"
    << " Φύλο: " << (ismale ? "Άνδρας" : "Γυναίκα") 
    << " Εξάμηνο: " << sem << endl;
}

UNI& UNI::operator++()
{
    sem++;
    return *this;
}

UNI UNI::operator++(int) 
{
    UNI temp = *this;
    sem++;
    return temp;
}

UNI &UNI::operator+=(unsigned int value) 
{
    sem += value;
    return *this;
}

UNI &UNI::operator-=(unsigned int value) {
    sem -= value;
    return *this;
}

UNI& UNI::operator-() 
{
    ismale = !ismale;
    return *this;
}