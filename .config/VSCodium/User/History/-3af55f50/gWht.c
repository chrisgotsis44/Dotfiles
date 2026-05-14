#include <stdlib.h>
#include <curses.h>

int main(int argc, char *argv[])
{
	int curx, cury;
	int ch;
	curx = cury = 10;
	initscr ();
	printw ("Hello world\n");
	refresh ();
	getch ();
	clear ();
	keypad (stdscr,TRUE);
	move(cury, curx);
	addch ('C');
	do
	{	
		ch = getch ();
		move(cury, curx);
		addch (' ');
		switch (ch)
		{
			case KEY_UP : cury--; break;
			case KEY_DOWN : cury++; break;
			case KEY_LEFT: curx--; break;
			case KEY_RIGHT: curx++; break;
		}
		move(cury, curx);
		addch ('C');
	}while (ch != 27);
	endwin ();
	
	return 0;
}
