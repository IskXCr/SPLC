extern void write(int k);
extern int read();

int do_main(){
    int N = 30;
    int num = 0, i = 1, k = 1;
    while(k <= N){
        while(i <= k){
            if(k == (k / i * i))
                num = num + 1;
            i = i + 1;
        }
        if(num == 2)
            write(k);
        i = 1;
        num = 0;
        k = k +1;
    }
    return 0;
}
