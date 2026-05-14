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

int main()
{

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

}