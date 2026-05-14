#include <iostream>
#include <cstdlib>
#include <ctime>
using namespace std;

class demigorgon
{
    public:
        demigorgon();
        int attack();
    private:
        int height;
        int weight;
        int health;
};

class demidog
{
    public:
        demidog();
        int attack();
    private:
        int health;
};

class hive
{
    public:
        hive(bool in_demigordon, int in_demidogs);
        int attack;
    private:
        demigorgon *demi_ptr;
        demidog *array_demidogs;
        int n_demidogs;
};

int main()
{
    srand(time(NULL));

    demidog d;

    cout<<d.attack();

    return 0;
}

demigorgon::demigorgon()
{
    height=5;
    weight=500;
    health=10000;
}

int demigorgon::attack()
{
    return 300+rand()%(500-300+1);
}

demidog::demidog()
{
    health=100;
}

int demidog::attack()
{
    return 10+rand()%(30-10+1);
}

hive::hive(bool in_demigordon, int in_demidogs)
{
    if(in_demigordon)
    {
        demi_ptr = new demigorgon;
        if(!demi_ptr) cout<<"Error Allocating Memory";
    }
    else 
        demi_ptr = NULL;

    array_demidogs = new demidog [in_demidogs];
    if(!array_demidogs) cout<<"Error Allocating Memory";

    n_demidogs = in_demidogs;
}

int hive::attack()
{
    int damage;

    if (demigorgon!=NULL)
    {
        damage = demi_ptr->attack();
        cout<<"Demigordon attacks! (damage:"<<damage<<")"<<endl;
    }
}