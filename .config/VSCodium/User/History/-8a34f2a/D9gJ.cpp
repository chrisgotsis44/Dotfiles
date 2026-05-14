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
        hive(bool in_demigordon);
        int attack();
    private:
        demigorgon *demi_ptr;
        demidog *array_demidogs;
        int n_demidogs;
};

int main()
{
    srand(time(NULL));

    hive h(true);

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

hive::hive(bool in_demigordon)
{
    if(in_demigordon)
    {
        demi_ptr = new demigorgon;
        if(!demi_ptr) cout<<"Error Allocating Memory";
    }
    else 
        demi_ptr = NULL;

    n_demidogs = 10+rand()%41;

    array_demidogs = new demidog [n_demidogs];
    if(!array_demidogs) cout<<"Error Allocating Memory";
}

int hive::attack()
{
    int damage;
    int sumDamage = 0;

    if (demi_ptr!=NULL)
    {
        damage = demi_ptr->attack();
        cout<<"Demigordon attacks! (damage:"<<damage<<")"<<endl;
        sumDamage += damage;
    }

    for(int i=0; i<n_demidogs; i++)
    {
        damage = array_demidogs[i].attack();
        cout<<"Demidog" <<i<<"attacks! (damage: "<<damage<<")"<<endl;
        sumDamage += damage;
    }

    return sumDamage;
}