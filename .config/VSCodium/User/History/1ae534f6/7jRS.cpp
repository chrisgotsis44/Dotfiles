#include <iostream>
#include <cstring>
using namespace std;

class STUD{
    public:
        STUD(const char * newam, const char * newname);
        STUD(const char * newam, const char * newname, bool gender, unsigned int newsem);
        STUD(const STUD&ob);
        ~STUD();
        void testprint();
        char *getam();
        char *getname();
        bool getgender();
        unsigned int getsem();
        void setam(const char *newam);
        void setname(const char *newname);
        void setgender(bool newgender);
        void setsem(unsigned int newsem);
        void print(ostream& os) const;
        STUD& operator++();                  
        STUD operator++(int);                
        STUD& operator+=(unsigned int val);  
        STUD& operator-=(unsigned int val);  
        STUD& operator-();
    private:
        char *am;
        char *name;
        bool ismale;
        unsigned int sem;
};

int main(){
    STUD *students = new STUD[3] {
        STUD("1001", "Νικόλαος Γεωργίου", true, 3), 
        STUD("1002", "Giannis Antetokumpo"),         
        STUD("1003", "Ελένη Κώστα", false, 6)       
    };

    students[0].print(cout);
    students[1].print(cout);
    students[2].print(cout);
    cout<<endl;
    ++students[0];
    students[0].print(cout);
    cout<<endl;
    -students[0];
    students[0].print(cout);
    cout<<endl;
    students[1] += 3;
    students[1].print(cout);

    delete[] students;

    return 0;
}

STUD::STUD(const char * newam, const char * newname){
    if(newname!=nullptr){
            name=new char [strlen(newname)+1];
            strcpy(name,newname);
    }else{
        cout<<"Try other name";
        name=nullptr;
    }
    if(newam!=nullptr){
        am=new char [strlen(newam)+1];
        strcpy(am,newam);
    }else{
        am=nullptr;
    }
    ismale=1;
    sem=1;
}

STUD::STUD(const char * newam, const char * newname, bool gender, unsigned int newsem){
    if(newname!=nullptr){
            name=new char [strlen(newname)+1];
            strcpy(name,newname);
    }else{
        cout<<"Try other name";
        name=nullptr;
    }
    if(newam!=nullptr){
        am=new char [strlen(newam)+1];
        strcpy(am,newam);
    }else{
        am=nullptr;
    }
    sem=newsem;
    ismale=gender;
}

STUD::STUD(const STUD&ob){
    if(ob.name!=nullptr){
            name = new char [strlen(ob.name)+1];
            strcpy(name,ob.name);
    }else{
        cout<<"Try other name";
        name=nullptr;
    }
    if(ob.am!=nullptr){
        am=new char [strlen(ob.am)+1];
        strcpy(am,ob.am);
    }else{
        am=nullptr;
    }
    sem = ob.sem;
    ismale = ob.ismale;
}

STUD::~STUD(){
    delete[] am;
    delete[] name;
}

char * STUD::getam(){
    return am;
}

char * STUD::getname(){
    return name;
}

bool STUD::getgender(){
    return ismale;
}

unsigned int STUD::getsem(){
    return sem;
}
 
void STUD::setam(const char *newam){
    delete[] am;
    if(newam!=nullptr){
        am=new char [strlen(newam)+1];
        strcpy(am,newam);
    }else{
        am=nullptr;
    }
}

void STUD::setname(const char *newname){
    delete[] name;
    if(newname!=nullptr){
            name=new char [strlen(newname)+1];
            strcpy(name,newname);
    }else{
        cout<<"Try other name";
        name=nullptr;
    }
}

void STUD::setgender(bool newgender){
    ismale=newgender;
}

void STUD::setsem(unsigned int newsem){
    sem=newsem;
}

void STUD::print(ostream& os) const {
    os << "AM: " << am 
    << " | Ονοματεπώνυμο: " << name << " (" << strlen(name) + 1 << ")"
    << " | Φύλο: " << (ismale ? "Άνδρας" : "Γυναίκα") 
    << " | Εξάμηνο: " << sem << endl;
}

STUD& STUD::operator++() {
    sem++;
    return *this;
}

STUD STUD::operator++(int) {
    STUD temp = *this;
    sem++;
    return temp;
}

STUD& STUD::operator+=(unsigned int val) {
    sem += val;
    return *this;
}

STUD& STUD::operator-=(unsigned int val) {
    sem -= val;
    return *this;
}

STUD& STUD::operator-() {
    ismale = !ismale;
    return *this;
}