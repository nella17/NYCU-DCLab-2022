/* ////////////////////////////////////////////////////////////////////////// */
/*  File   : ppm2mem.c                                                        */
/*  Author : Chun-Jen Tsai                                                    */
/*  Date   : 12/02/2018                                                       */
/* -------------------------------------------------------------------------- */
/*  This program converts a 24-bit PPM image to a 12-bit raw image Verilog    */
/*  memory data file.                                                         */
/* ////////////////////////////////////////////////////////////////////////// */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

unsigned char buf[320*240*3];

void usage(char *arg, FILE *fp)
{
    fprintf(stderr, "\nConvert several ppm images into a single Verilog memory file.\n", arg);
    fprintf(stderr, "Usage: %1 input1.ppm input2.ppm ... \n", arg);
    fprintf(stderr, "Note: the output is images.mem\n");
    if (fp != NULL) fclose(fp);
    exit(-1);
}

int main(int argc, char **argv)
{
    int width, height, idx;
    int count = 1;  // file counter
    FILE *fp = NULL, *ofp;

    if (argc < 2) usage(*argv, fp);

    memset(buf, 0, sizeof(buf));
    while (count < argc)
    {
        if ((fp = fopen(argv[count], "rb")) == NULL)
        {
            fprintf(stderr, "%s: input file '%s' open error.\n", *argv, argv[count]);
            return -1;
        }
        fgets(buf, sizeof(buf), fp); // read image color type
        fgets(buf, sizeof(buf), fp); // read image width & height
        if (sscanf(buf, "%d %d", &width, &height) != 2)
        {
            fprintf(stderr, "%s: image format error.\n", *argv);
            fclose(fp);
            return -1;
        }
        if (width > 320 || height > 240)
        {
            fprintf(stderr, "%s: image size too large.\n", *argv);
            fclose(fp);
            return -1;
        }
        fgets(buf, sizeof(buf), fp); // read depth per pixel per channel
        if (fread(buf, width*3, height, fp) != height) // read the wntire image
        {
            fprintf(stderr, "%s: image data read error.\n", *argv);
            fclose(fp);
            return -1;
        }
        else
            fclose(fp);

        if ((ofp = fopen("images.mem", "at")) == NULL)
        {
            fprintf(stderr, "%s: output file 'images.mem' open error.\n", *argv);
            return -1;
        }
        for (idx = 0; idx < width*height; idx++)
        {
            int color = buf[3*idx+0] | buf[3*idx+1] | buf[3*idx+2];
            if (color == 0)
                fprintf(ofp, "0f0\n");
            else
                fprintf(ofp, "%1x%1x%1x\n", buf[3*idx+0] >> 4, buf[3*idx+1] >> 4, buf[3*idx+2] >> 4);
        }
        fclose(ofp);
        count++;
    }
    return 0;
}
