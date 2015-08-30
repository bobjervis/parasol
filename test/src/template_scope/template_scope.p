import parasollanguage.org:template;

template.Template<double> bar(4.5);

assert(bar.data() == 6.5);
