#include <iostream>
using namespace std;

inline int sqrt(int x);

int main()
{
    cout<<sqrt(4);

    return 0;
}

int sqrt(int x)
{
    return x*x;
}