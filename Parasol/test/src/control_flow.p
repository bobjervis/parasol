int main(string[] args) {
	int i = 4;
	int j = 5;
	int k = 7, m = 22;
	
	if (k < m)
		print("k < m\n");
	else
		assert(false);
	if (i == j)
		assert(false);
	else
		print("i != j\n");
	int count = 0;
	while (i < k) {
		i++;
		count++;
	}
	assert(count == 3);
	assert(i == k);

	count = 0;
	do {
		i++;
		count++;
	} while (i < m);
	assert(count == 15);
	assert(i == m);
	for (i = 5; i < 20; i++) {
		j += i;
		if (j > 40)
			break;
		if (j < 41)
			continue;
		j += 56;
	}
	assert(j == 50);
	j = 5;
	for (byte i = 5; i < 20; i++) {
		j += i;
		if (j > 40)
			break;
		if (j < 41)
			continue;
		j += 56;
	}
	assert(j == 50);
	j = 5;
	i = 5;
	while (i < 20) {
		j += i;
		if (j > 40)
			break;
		if (j < 41) {
			i++;
			continue;
		}
		j += 56;
	}
	j = 5;
	i = 5;
	do {
		j += i;
		if (j > 40)
			break;
		if (j < 41) {
			i++;
			continue;
		}
		j += 56;
	} while (i < 20);
	assert(j == 50);
	assert(basicSwitchTest(1) == 3);
	assert(basicSwitchTest(2) == 4);
	assert(basicSwitchTest(3) == 0);
	assert(defaultSwitchTest(1) == 3);
	assert(defaultSwitchTest(2) == 4);
	assert(defaultSwitchTest(3) == 1);
	i = 10;
	for (;;) {
		if (i <= 0)
			break;
		i--;
	}
	assert(i == 0);
	forScopeTest();
	return 0;
}

int basicSwitchTest(int path) {
	switch (path) {
	case 1:
		return 3;
		
	case 2:
		return 4;
	}
	return 0;
}

int defaultSwitchTest(int path) {
	switch (path) {
	case 1:
		return 3;
		
	case 2:
		return 4;
		
	default:
		return 1;
	}
	return 7;
}

void forScopeTest() {
	boolean flag = false;
	
	for (int i = 0; i < 5; i++)
		if (i > 3) {
			flag = true;
		}
	assert(flag == true);
}
