#include <iostream>
using namespace std;

class dummy{
    public:
        dummy();
        ~dummy();
        int x;
};

void f(dummy ob);

int main()
{
    dummy d; //Kaleitai o contructor

    f(d);

    return 0;
}

dummy::dummy()
{
    cout<<"Constructing..."<<endl;
}

dummy::~dummy()
{
    cout<<"Distructing..."<<endl;
}

void f(dummy ob)
{

}