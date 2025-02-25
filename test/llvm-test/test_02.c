extern void write(int k);
extern int read();

int calculateBinomialCoefficient(int row, int col) {
    int coefficient = 1;
    int i = 0;

    if (row < col) {
        return 0;
    }
    
    if (col > row - col) {
        col = row - col;
    }
    
    while (i < col) {
        coefficient = coefficient * (row - i);
        coefficient = coefficient / (i + 1);
        i=i+1;
    }
    
    return coefficient;
}

int do_main() {
    int r, c, coe;
    r = read();
    c = read();
    coe = calculateBinomialCoefficient(r, c);
    write(coe);
    return 0;
}
