#include <iostream>
using namespace std;

#define N 3

class tictactoe{
    public:
        tictactoe();
        bool play(int x, int y);
        char checkwinner();
        void print();
        void nextPlayer();
        char getPlayer() const;
    private:
        char array[N][N];
        char player;
};

int main()
{
    tictactoe t;
    int x,y,step=0;

    while(true)
    {
        cout<<endl<<"Plaisio"<<endl;
        t.print();
        cout<<endl<<"Paizei o "<<t.getPlayer()<<endl;
        
        cout<<"Dwse X syntetagmeni: ";
        cin>>x;
        if(x<0 || x>2)
        {
            cout<<"Lathos! Oi sintetagmenes einai apo 0-2";
            continue;
        }
        cout<<"Dwse Y syntetagmeni: ";
        cin>>y;
        if(y<0 || y>2)
        {
            cout<<"Lathos! Oi sintetagmenes einai apo 0-2";
            continue;
        }

        if(!t.play(x,y)
        {
            cout<<"Lathos Kinisi";
            continue;
        }else
            step++;

        if(t.checkwinner()!='-')
        {
            cout<<"Nikise o "<<t.checkwinner();
            t.print();
            break;
        }else if(step==9)
        {
            cout<<"Isopalia";
            t.print();
            break;
        }
    }

    return 0;
}

tictactoe::tictactoe()
{
    int i,j;

    for(i=0; i<N; i++)
        for(j=0; j<N; j++)
            array[i][j]='-';

    player = 'X';
}

bool tictactoe::play(int x, int y)
{
    if(array[x][y]=='-')
    {
        if(c=='X'||c=='O')
        {
            array[x][y]=player;
            return true;
        }
        else 
            return false;
    }
    else
        return false;
}

char tictactoe::checkwinner()
{
    int i,j;

    /*Grammes*/
    for(i=0; i<N; i++)
    {
        if(array[i][0] != '-' && array[i][0]==array[i][1] && array[i][1]==array[i][2])
            return array[i][0];
    }

    /*Stiles*/
    for(j=0; j<N; j++)
    {
        if(array[0][j] != '-' && array[0][j]==array[1][j] && array[1][j]==array[2][j])
            return array[0][j];
    }

    /*Diagwnious*/
    if(array[0][0] != '-' && array[0][0]==array[1][1] && array[1][1]==array[2][2])
        return array[0][0];

    if(array[0][2] != '-' && array[0][2]==array[1][1] && array[1][1]==array[2][0])
        return array[0][2];

    return '-';
}

void tictactoe::print()
{
    int i,j;

    for(i=0; i<N; i++)
    {
        for(j=0; j<N; j++)
            cout<<array[i][j];
        cout<<endl;
    }       
}

void tictactoe::nextPlayer()
{
    if(player == 'X')
            player = 'O';
        else 
            player = 'X';
}

char tictactoe::getPlayer() const
{
    return player;
}