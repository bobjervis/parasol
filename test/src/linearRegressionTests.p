import parasol:math.regression;

regression.LinearRegression<float> r;

float[] indep, dep;

indep.append(1.0f);
indep.append(2.0f);
indep.append(3.0f);

dep.append(0.5f);
dep.append(0.7f);
dep.append(0.9f);

r.dependent(dep);
r.independent(indep);

r.ordinaryLeastSquares();

printf("alpha= %f\n", r.alpha());
printf("beta=  %f\n", r.beta());

float[] error = r.error();

assert(error.length() == 3);

for (int i = 0; i < error.length(); i++)
	printf("Error[%d] = %f\n", i, error[i]);
