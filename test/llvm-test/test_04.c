extern void write(int k);
extern int read();

int mod(int x, int n) { return x - (x / n) * n; }

int isPerfectNumber(int number)
{
    int sum = 0;
    int j = 1;
    while (j <= number / 2) {
        if (mod(number, j) == 0) {
            sum = sum + j;
        }
        j = j + 1;
    }

    if (sum == number) {
        return 1;
    }
    else {
        return 0;
    }
}

int do_main()
{
    int count = 0;
    int i = 1;
    while (i <= 100) {
        if (isPerfectNumber(i) == 1) {
            write(i);
        }
        i = i + 1;
    }

    return 0;
}