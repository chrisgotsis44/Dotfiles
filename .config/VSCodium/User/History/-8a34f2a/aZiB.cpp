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