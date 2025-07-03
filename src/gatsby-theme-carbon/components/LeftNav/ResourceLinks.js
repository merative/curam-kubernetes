import React from 'react';
import ResourceLinks from 'gatsby-theme-carbon/src/components/LeftNav/ResourceLinks';

const links = [
  {
    title: 'GitHub',
    href: 'https://github.com/merative/curam-kubernetes',
  },
  {
    title: 'Change Log',
    href: 'https://github.com/merative/curam-kubernetes/blob/main/CHANGELOG.md',
  }
];

// shouldOpenNewTabs: true if outbound links should open in a new tab
const CustomResources = () => <ResourceLinks shouldOpenNewTabs links={links} />;

export default CustomResources;
