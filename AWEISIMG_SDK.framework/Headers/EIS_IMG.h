#pragma once
#ifndef __EIS_IMG_H__
#define __EIS_IMG_H__

struct EIS_Params
{
	int  input_width=1920;
	int  input_height=1080;
	double trimRatio = 0.1;
	int  radius = 120;	

	float acc_para = 8.0;
	int   size= 4;
	float thresh=5.0;
	float eps=0.1;

	int  output_width = 1536;
	int  output_height = 864;

	// scene detection para
	float low_light_thresh = 50.0f;
	float motion_thresh = 120.0f;
	float wave_thresh = 80.0f;
	float distort_thresh = 0.4f;
	float low_texture_thresh = 15.0f;
	int   min_features = 50;
	int   motion_window = 10;
};

struct EIS_Context;

EIS_Context* img_eis_init(EIS_Params* para, const char* license_file);
// format 0->4 : yu12,yv12,nv12,nv21
int img_eis_stabilization(EIS_Context* ctx, const char* buffer_in, int input_fmt, char* buffer_out, int output_fmt);
void img_eis_release(EIS_Context* ctx);


#endif